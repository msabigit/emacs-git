(require 'easy-mmode)
(defcustom diff-whitespace-style '(face trailing)
  "Specify `whitespace-style' variable for `diff-mode' buffers."
  :require 'whitespace
  :type (get 'whitespace-style 'custom-type)
  :version "29.1")

(defvar-keymap diff-mode-shared-map
  :parent special-mode-map
  "n" #'diff-hunk-next
  "N" #'diff-file-next
  "p" #'diff-hunk-prev
  "P" #'diff-file-prev
  "TAB" #'diff-hunk-next
  "<backtab>" #'diff-hunk-prev
  "k" #'diff-hunk-kill
  "K" #'diff-file-kill
  "}" #'diff-file-next                  ; From compilation-minor-mode.
  "{" #'diff-file-prev
  "RET" #'diff-goto-source
  "<mouse-2>" #'diff-goto-source
  "W" #'widen
  "o" #'diff-goto-source                ; other-window
  "A" #'diff-ediff-patch
  "r" #'diff-restrict-view
  "R" #'diff-reverse-direction
  "<remap> <undo>" #'diff-undo)

(defvar-keymap diff-mode-map
  :doc "Keymap for `diff-mode'.  See also `diff-mode-shared-map'."
  "ESC" (let ((map (define-keymap :parent diff-mode-shared-map)))
          ;; We want to inherit most bindings from
          ;; `diff-mode-shared-map', but not all since they may hide
          ;; useful `M-<foo>' global bindings when editing.
          (dolist (key '("A" "r" "R" "g" "q" "W" "z"))
            (keymap-set map key nil))
          map)
  ;; From compilation-minor-mode.
  "C-c C-c" #'diff-goto-source
  ;; By analogy with the global C-x 4 a binding.
  "C-x 4 A" #'diff-add-change-log-entries-other-window
  ;; Misc operations.
  "C-c C-a" #'diff-apply-hunk
  "C-c C-e" #'diff-ediff-patch
  "C-c C-n" #'diff-restrict-view
  "C-c C-s" #'diff-split-hunk
  "C-c C-t" #'diff-test-hunk
  "C-c C-r" #'diff-reverse-direction
  "C-c C-u" #'diff-context->unified
  ;; `d' because it duplicates the context :-(  --Stef
  "C-c C-d" #'diff-unified->context
  "C-c C-w" #'diff-ignore-whitespace-hunk
  ;; `l' because it "refreshes" the hunk like C-l refreshes the screen
  "C-c C-l" #'diff-refresh-hunk
  "C-c C-b" #'diff-refine-hunk        ;No reason for `b' :-(
  "C-c C-f" #'next-error-follow-minor-mode)
  :type '(choice (string "ESC")
                 (string "\C-c=") string))
(defvar-keymap diff-minor-mode-map
  :doc "Keymap for `diff-minor-mode'.  See also `diff-mode-shared-map'."
  (key-description diff-minor-mode-prefix) diff-mode-shared-map)
(with-suppressed-warnings ((obsolete diff-auto-refine-mode))
  (define-minor-mode diff-auto-refine-mode
    "Toggle automatic diff hunk finer highlighting (Diff Auto Refine mode).
    :group 'diff-mode :init-value nil :lighter nil ;; " Auto-Refine"
    (if diff-auto-refine-mode
        (progn
          (customize-set-variable 'diff-refine 'navigation)
          (condition-case-unless-debug nil (diff-refine-hunk) (error nil)))
      (customize-set-variable 'diff-refine nil))))
        (when (re-search-forward regexp-file (line-end-position 4) t) ; File header.
(defun diff--outline-level ()
  (if (string-match-p diff-hunk-header-re (match-string 0))
      2 1))
(defvar-local diff-mode-read-only nil
  "Non-nil when read-only diff buffer uses short keys.")

;; It should be lower than `outline-minor-mode' and `view-mode'.
(or (assq 'diff-mode-read-only minor-mode-map-alist)
    (nconc minor-mode-map-alist
           (list (cons 'diff-mode-read-only diff-mode-shared-map))))

  ;; read-only setup
  (when diff-default-read-only
    (setq buffer-read-only t))
  (when buffer-read-only
    (setq diff-mode-read-only t))
  (add-hook 'read-only-mode-hook
            (lambda ()
              (setq diff-mode-read-only buffer-read-only))
            nil t)


  (diff-setup-buffer-type))
  (setq-local whitespace-style diff-whitespace-style)
(defun diff-setup-buffer-type ()
  "Try to guess the `diff-buffer-type' from content of current Diff mode buffer.
`outline-regexp' is updated accordingly."
  (save-excursion
    (goto-char (point-min))
    (setq-local diff-buffer-type
                (if (re-search-forward "^diff --git" nil t)
                    'git
                  nil)))
  (when (eq diff-buffer-type 'git)
    (setq diff-outline-regexp
          (concat "\\(^diff --git.*\n\\|" diff-hunk-header-re "\\)")))
  (setq-local outline-level #'diff--outline-level)
  (setq-local outline-regexp diff-outline-regexp))

    (catch 'malformed
      (let* ((beg (or (ignore-errors (diff-beginning-of-hunk))
                      (ignore-errors (diff-hunk-next) (point))
                      max)))
        (while (< beg max)
          (goto-char beg)
          (unless (looking-at diff-hunk-header-re)
            (throw 'malformed nil))
          (let ((end
                 (save-excursion (diff-end-of-hunk) (point))))
            (unless (< beg end)
              (throw 'malformed nil))
            (funcall fun beg end)
            (goto-char end)
            (setq beg (if (looking-at diff-hunk-header-re)
                          end
                        (or (ignore-errors (diff-hunk-next) (point))
                            max)))))))))
;;;###autoload
(defcustom diff-add-log-use-relative-names nil
  "Use relative file names when generating ChangeLog skeletons.
The files will be relative to the root directory of the VC
repository.  This option affects the behavior of
`diff-add-log-current-defuns'."
  :type 'boolean
  :safe #'booleanp
  :version "29.1")

where DEFUN... is a list of function names found in FILE.  If
`diff-add-log-use-relative-names' is non-nil, file names in the alist
are relative to the root directory of the VC repository."
        (pcase-let* ((filename (substring-no-properties
                                (if diff-add-log-use-relative-names
                                    (file-relative-name
                                     (diff-find-file-name)
                                     (vc-root-dir))
                                  (diff-find-file-name))))
    (when (> (frame-parameter nil 'left-fringe) 0)
      (save-excursion
        ;; FIXME: Include the first space for context-style hunks!
        (while (re-search-forward "^[-+! ]" limit t)
          (unless (eq (get-text-property (match-beginning 0) 'face)
                      'diff-header)
            (put-text-property
             (match-beginning 0) (match-end 0)
             'display
             (alist-get
              (char-before)
              '((?+ . (left-fringe diff-fringe-add diff-indicator-added))
                (?- . (left-fringe diff-fringe-del diff-indicator-removed))
                (?! . (left-fringe diff-fringe-rep diff-indicator-changed))
                (?\s . (left-fringe diff-fringe-nul fringe)))))))))
    ;; FIXME: Add support for Git's "rename from/to"?
      ;; We split the regexp match into a search plus a looking-at because
      ;; we want to use LIMIT for the search but we still want to match
      ;; all the header's lines even if LIMIT falls in the middle of it.
                 (let* ((index "\\(?:index.*\n\\)?")
                        (file4 (concat
                                "\\(?:" null-device "\\|[ab]/\\(?4:.*\\)\\)"))
                        (file5 (concat
                                "\\(?:" null-device "\\|[ab]/\\(?5:.*\\)\\)"))
                        (header (concat "--- " file4 "\n"
                                        "\\+\\+\\+ " file5 "\n"))
                        (binary (concat
                                 "Binary files " file4
                                 " and " file5 " \\(?7:differ\\)\n"))
                        (horb (concat "\\(?:" header "\\|" binary "\\)?")))
                   (concat "diff.*?\\(?: a/\\(.*?\\) b/\\(.*\\)\\)?\n"
                           "\\(?:"
                           ;; For new/deleted files, there might be no
                           ;; header (and no hunk) if the file is/was empty.
                           "\\(?3:new\\(?6:\\)\\|deleted\\) file mode \\(?10:[0-7]\\{6\\}\\)\n"
                           index horb
                           ;; Normal case. There might be no header
                           ;; (and no hunk) if only the file mode
                           ;; changed.
                           "\\|"
                           "\\(?:old mode \\(?8:[0-7]\\{6\\}\\)\n\\)?"
                           "\\(?:new mode \\(?9:[0-7]\\{6\\}\\)\n\\)?"
                           index horb "\\)")))))
        ;; The file names can be extracted either from the `diff' line
        ;; or from the two header lines.  Prefer the header line info if
        ;; available since the `diff' line is ambiguous in case the
        ;; file names include " b/" or " a/".
        ;; FIXME: This prettification throws away all the information
        ;; about the index hashes.
        (let ((oldfile (or (match-string 4) (match-string 1)))
              (newfile (or (match-string 5) (match-string 2)))
              (kind (if (match-beginning 7) " BINARY"
                      (unless (or (match-beginning 4)
                                  (match-beginning 5)
                                  (not (match-beginning 3)))
                        " empty")))
              (filemode
               (cond
                ((match-beginning 10)
                 (concat " file with mode " (match-string 10) "  "))
                ((and (match-beginning 8) (match-beginning 9))
                 (concat " file (mode changed from "
                         (match-string 8) " to " (match-string 9) ")  "))
                (t " file  "))))
          (add-text-properties
           (match-beginning 0) (1- (match-end 0))
           (list 'display
                 (propertize
                  (cond
                   ((match-beginning 3)
                    (concat (capitalize (match-string 3)) kind filemode
                            (if (match-beginning 6) newfile oldfile)))
                   ((and (null (match-string 4)) (match-string 5))
                    (concat "New " kind filemode newfile))
                   ((null (match-string 2))
                    ;; We used to use
                    ;;     (concat "Deleted" kind filemode oldfile)
                    ;; here but that misfires for `diff-buffers'
                    ;; (see 24 Jun 2022 message in bug#54034).
                    ;; AFAIK if (match-string 2) is nil then so is
                    ;; (match-string 1), so "Deleted" doesn't sound right,
                    ;; so better just let the header in plain sight for now.
                    ;; FIXME: `diff-buffers' should maybe try to better
                    ;; mimic Git's format with "a/" and "b/" so prettification
                    ;; can "just work!"
                    nil)
                   (t
                    (concat "Modified" kind filemode oldfile)))
                  'face '(diff-file-header diff-header))
                 'font-lock-multiline t))))))
                (or (with-demoted-errors "Error getting hunk text: %S"
                      (diff-hunk-text hunk (not old) nil))
;;;###autoload
(defun diff-vc-deduce-fileset ()
  (let ((backend (vc-responsible-backend default-directory))
        files)
    (save-excursion
      (goto-char (point-min))
      (while (progn (diff-file-next) (not (eobp)))
        (push (diff-find-file-name nil t) files)))
    (list backend (nreverse files) nil nil 'patch)))