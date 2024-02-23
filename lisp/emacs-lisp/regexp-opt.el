;;; regexp-opt.el --- generate efficient regexps to match strings -*- lexical-binding: t -*-

;; Copyright (C) 1994-2024 Free Software Foundation, Inc.

;; Author: Simon Marshall <simon@gnu.org>
;; Maintainer: emacs-devel@gnu.org
;; Keywords: strings, regexps, extensions

;; This file is part of GNU Emacs.

;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; The "opt" in "regexp-opt" stands for "optim\\(al\\|i[sz]e\\)".
;;
;; This package generates a regexp from a given list of strings (which matches
;; one of those strings) so that the regexp generated by:
;;
;; (regexp-opt strings)
;;
;; is equivalent to, but more efficient than, the regexp generated by:
;;
;; (mapconcat 'regexp-quote strings "\\|")
;;
;; For example:
;;
;; (let ((strings '("cond" "if" "when" "unless" "while"
;; 		    "let" "let*" "progn" "prog1" "prog2"
;; 		    "save-restriction" "save-excursion" "save-window-excursion"
;; 		    "save-current-buffer" "save-match-data"
;; 		    "catch" "throw" "unwind-protect" "condition-case")))
;;   (concat "(" (regexp-opt strings t) "\\>"))
;;  => "(\\(c\\(atch\\|ond\\(ition-case\\)?\\)\\|if\\|let\\*?\\|prog[12n]\\|save-\\(current-buffer\\|excursion\\|match-data\\|restriction\\|window-excursion\\)\\|throw\\|un\\(less\\|wind-protect\\)\\|wh\\(en\\|ile\\)\\)\\>"
;;
;; Searching using the above example `regexp-opt' regexp takes approximately
;; two-thirds of the time taken using the equivalent `mapconcat' regexp.

;; Since this package was written to produce efficient regexps, not regexps
;; efficiently, it is probably not a good idea to in-line too many calls in
;; your code, unless you use the following trick with `eval-when-compile':
;;
;; (defvar definition-regexp
;;   (eval-when-compile
;;     (concat "^("
;;             (regexp-opt '("defun" "defsubst" "defmacro" "defalias"
;;                           "defvar" "defconst") t)
;;             "\\>")))
;;
;; The `byte-compile' code will be as if you had defined the variable thus:
;;
;; (defvar definition-regexp
;;   "^(\\(def\\(alias\\|const\\|macro\\|subst\\|un\\|var\\)\\)\\>")
;;
;; Note that if you use this trick for all instances of `regexp-opt' and
;; `regexp-opt-depth' in your code, regexp-opt.el would only have to be loaded
;; at compile time.  But note also that using this trick means that should
;; regexp-opt.el be changed, perhaps to fix a bug or to add a feature to
;; improve the efficiency of `regexp-opt' regexps, you would have to recompile
;; your code for such changes to have effect in your code.

;; Originally written for font-lock.el, from an idea from Stig's hl319.el, with
;; thanks for ideas also to Michael Ernst, Bob Glickstein, Dan Nicolaescu and
;; Stefan Monnier.
;; No doubt `regexp-opt' doesn't always produce optimal regexps, so code, ideas
;; or any other information to improve things are welcome.
;;
;; One possible improvement would be to compile '("aa" "ab" "ba" "bb")
;; into "[ab][ab]" rather than "a[ab]\\|b[ab]".  I'm not sure it's worth
;; it but if someone knows how to do it without going through too many
;; contortions, I'm all ears.

;;; Code:

;;;###autoload
(defun regexp-opt (strings &optional paren)
  "Return a regexp to match a string in the list STRINGS.
Each member of STRINGS is treated as a fixed string, not as a regexp.
Optional PAREN specifies how the returned regexp is surrounded by
grouping constructs.

If STRINGS is the empty list, the return value is a regexp that
never matches anything.

The optional argument PAREN can be any of the following:

a string
    the resulting regexp is preceded by PAREN and followed by
    \\), e.g.  use \"\\\\(?1:\" to produce an explicitly numbered
    group.

`words'
    the resulting regexp is surrounded by \\=\\<\\( and \\)\\>.

`symbols'
    the resulting regexp is surrounded by \\_<\\( and \\)\\_>.

non-nil
    the resulting regexp is surrounded by \\( and \\).

nil
    the resulting regexp is surrounded by \\(?: and \\), if it is
    necessary to ensure that a postfix operator appended to it will
    apply to the whole expression.

The returned regexp is ordered in such a way that it will always
match the longest string possible.

Up to reordering, the resulting regexp is equivalent to but
usually more efficient than that of a simplified version:

 (defun simplified-regexp-opt (strings &optional paren)
   (let ((parens
          (cond ((stringp paren)       (cons paren \"\\\\)\"))
                ((eq paren \\='words)    \\='(\"\\\\\\=<\\\\(\" . \"\\\\)\\\\>\"))
                ((eq paren \\='symbols) \\='(\"\\\\_<\\\\(\" . \"\\\\)\\\\_>\"))
                ((null paren)          \\='(\"\\\\(?:\" . \"\\\\)\"))
                (t                       \\='(\"\\\\(\" . \"\\\\)\")))))
     (concat (car parens)
             (mapconcat \\='regexp-quote strings \"\\\\|\")
             (cdr parens))))"
  (declare (function (list) string)
           (pure t) (side-effect-free t))
  (save-match-data
    ;; Recurse on the sorted list.
    (let* ((max-lisp-eval-depth 10000)
	   (completion-ignore-case nil)
	   (completion-regexp-list nil)
	   (open (cond ((stringp paren) paren) (paren "\\(")))
	   (re (if strings
                   (regexp-opt-group
                    (delete-dups (sort (copy-sequence strings) 'string-lessp))
                    (or open t) (not open))
                 ;; No strings: return an unmatchable regexp.
                 (concat (or open "\\(?:") regexp-unmatchable "\\)"))))
      (cond ((eq paren 'words)
	     (concat "\\<" re "\\>"))
	    ((eq paren 'symbols)
	     (concat "\\_<" re "\\_>"))
	    (t re)))))

;;;###autoload
(defun regexp-opt-depth (regexp)
  "Return the depth of REGEXP.
This means the number of non-shy regexp grouping constructs
\(parenthesized expressions) in REGEXP."
  (declare (pure t) (side-effect-free t))
  (save-match-data
    ;; Hack to signal an error if REGEXP does not have balanced parentheses.
    (string-match regexp "")
    ;; Count the number of open parentheses in REGEXP.
    (let ((count 0) start last)
      (while (string-match "\\\\(\\(\\?[0-9]*:\\)?" regexp start)
	(setq start (match-end 0))	      ; Start of next search.
	(when (and (not (match-beginning 1))
		   (subregexp-context-p regexp (match-beginning 0) last))
	  ;; It's not a shy group and it's not inside brackets or after
	  ;; a backslash: it's really a group-open marker.
	  (setq last start)	    ; Speed up next regexp-opt-re-context-p.
	  (setq count (1+ count))))
      count)))

;;; Workhorse functions.

(defun regexp-opt-group (strings &optional paren lax)
  "Return a regexp to match a string in the sorted list STRINGS.
If PAREN non-nil, output regexp parentheses around returned regexp.
If LAX non-nil, don't output parentheses if it doesn't require them.
Merges keywords to avoid backtracking in Emacs's regexp matcher."
  ;; The basic idea is to find the shortest common prefix or suffix, remove it
  ;; and recurse.  If there is no prefix, we divide the list into two so that
  ;; (at least) one half will have at least a one-character common prefix.

  ;; Also we delay the addition of grouping parenthesis as long as possible
  ;; until we're sure we need them, and try to remove one-character sequences
  ;; so we can use character sets rather than grouping parenthesis.
  (let* ((open-group (cond ((stringp paren) paren) (paren "\\(?:") (t "")))
	 (close-group (if paren "\\)" ""))
	 (open-charset (if lax "" open-group))
	 (close-charset (if lax "" close-group)))
    (cond
     ;;
     ;; If there are no strings, just return the empty string.
     ((= (length strings) 0)
      "")
     ;;
     ;; If there is only one string, just return it.
     ((= (length strings) 1)
      (if (= (length (car strings)) 1)
	  (concat open-charset (regexp-quote (car strings)) close-charset)
	(concat open-group (regexp-quote (car strings)) close-group)))
     ;;
     ;; If there is an empty string, remove it and recurse on the rest.
     ((= (length (car strings)) 0)
      (concat open-charset
	      (regexp-opt-group (cdr strings) t t) "?"
	      close-charset))
     ;;
     ;; If there are several one-char strings, use charsets
     ((and (= (length (car strings)) 1)
	   (let ((strs (cdr strings)))
	     (while (and strs (/= (length (car strs)) 1))
	       (pop strs))
	     strs))
      (let (letters rest)
	;; Collect one-char strings
	(dolist (s strings)
	  (if (= (length s) 1) (push (string-to-char s) letters) (push s rest)))

	(if rest
	    ;; several one-char strings: take them and recurse
	    ;; on the rest (first so as to match the longest).
	    (concat open-group
		    (regexp-opt-group (nreverse rest))
		    "\\|" (regexp-opt-charset letters)
		    close-group)
	  ;; all are one-char strings: just return a character set.
	  (concat open-charset
		  (regexp-opt-charset letters)
		  close-charset))))
     ;;
     ;; We have a list of different length strings.
     (t
      (let ((prefix (try-completion "" strings)))
	(if (> (length prefix) 0)
	    ;; common prefix: take it and recurse on the suffixes.
	    (let* ((n (length prefix))
		   (suffixes (mapcar (lambda (s) (substring s n)) strings)))
	      (concat open-group
		      (regexp-quote prefix)
		      (regexp-opt-group suffixes t t)
		      close-group))

	  (let* ((sgnirts (mapcar #'reverse strings))
		 (xiffus (try-completion "" sgnirts)))
	    (if (> (length xiffus) 0)
		;; common suffix: take it and recurse on the prefixes.
		(let* ((n (- (length xiffus)))
		       (prefixes
			;; Sorting is necessary in cases such as ("ad" "d").
			(sort (mapcar (lambda (s) (substring s 0 n)) strings)
			      'string-lessp)))
		  (concat open-group
			  (regexp-opt-group prefixes t t)
			  (regexp-quote (nreverse xiffus))
			  close-group))

	      ;; Otherwise, divide the list into those that start with a
	      ;; particular letter and those that do not, and recurse on them.
	      (let* ((char (substring-no-properties (car strings) 0 1))
		     (half1 (all-completions char strings))
		     (half2 (nthcdr (length half1) strings)))
		(concat open-group
			(regexp-opt-group half1)
			"\\|" (regexp-opt-group half2)
			close-group))))))))))


(defun regexp-opt-charset (chars)
  "Return a regexp to match a character in CHARS.
CHARS should be a list of characters.
If CHARS is the empty list, the return value is a regexp that
never matches anything."
  (declare (pure t) (side-effect-free t))
  ;; The basic idea is to find character ranges.  Also we take care in the
  ;; position of character set meta characters in the character set regexp.
  ;;
  (let* ((charmap (make-char-table 'regexp-opt-charset))
	 (start -1) (end -2)
	 (charset "")
	 (bracket "") (dash "") (caret ""))
    ;;
    ;; Make a character map but extract character set meta characters.
    (dolist (char chars)
      (cond
       ((eq char ?\])
	(setq bracket "]"))
       ((eq char ?^)
	(setq caret "^"))
       ((eq char ?-)
	(setq dash "-"))
       (t
	(aset charmap char t))))
    ;;
    ;; Make a character set from the map using ranges where applicable.
    (map-char-table
     (lambda (c v)
       (when v
	 (if (consp c)
	     (if (= (1- (car c)) end) (setq end (cdr c))
	       (if (> end (+ start 2))
		   (setq charset (format "%s%c-%c" charset start end))
		 (while (>= end start)
		   (setq charset (format "%s%c" charset start))
		   (setq start (1+ start))))
	       (setq start (car c) end (cdr c)))
	   (if (= (1- c) end) (setq end c)
	     (if (> end (+ start 2))
	       (setq charset (format "%s%c-%c" charset start end))
	     (while (>= end start)
	       (setq charset (format "%s%c" charset start))
	       (setq start (1+ start))))
	     (setq start c end c)))))
     charmap)
    (when (>= end start)
      (if (> end (+ start 2))
	  (setq charset (format "%s%c-%c" charset start end))
	(while (>= end start)
	  (setq charset (format "%s%c" charset start))
	  (setq start (1+ start)))))

    ;; Make sure that ] is first, ^ is not first, - is first or last.
    (let ((all (concat bracket charset caret dash)))
      (pcase (length all)
        (0 regexp-unmatchable)
        (1 (regexp-quote all))
        (_ (if (string-equal all "^-")
               "[-^]"
             (concat "[" all "]")))))))


(provide 'regexp-opt)

;;; regexp-opt.el ends here
