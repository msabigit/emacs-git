(easy-mmode-defmap diff-mode-shared-map
  '(("n" . diff-hunk-next)
    ("N" . diff-file-next)
    ("p" . diff-hunk-prev)
    ("P" . diff-file-prev)
    ("\t" . diff-hunk-next)
    ([backtab] . diff-hunk-prev)
    ("k" . diff-hunk-kill)
    ("K" . diff-file-kill)
    ("}" . diff-file-next)	; From compilation-minor-mode.
    ("{" . diff-file-prev)
    ("\C-m" . diff-goto-source)
    ([mouse-2] . diff-goto-source)
    ("W" . widen)
    ("o" . diff-goto-source)	; other-window
    ("A" . diff-ediff-patch)
    ("r" . diff-restrict-view)
    ("R" . diff-reverse-direction)
    ([remap undo] . diff-undo))
  "Basic keymap for `diff-mode', bound to various prefix keys."
  :inherit special-mode-map)

(easy-mmode-defmap diff-mode-map
  `(("\e" . ,(let ((map (make-sparse-keymap)))
               ;; We want to inherit most bindings from diff-mode-shared-map,
               ;; but not all since they may hide useful M-<foo> global
               ;; bindings when editing.
               (set-keymap-parent map diff-mode-shared-map)
               (dolist (key '("A" "r" "R" "g" "q" "W" "z"))
                 (define-key map key nil))
               map))
    ;; From compilation-minor-mode.
    ("\C-c\C-c" . diff-goto-source)
    ;; By analogy with the global C-x 4 a binding.
    ("\C-x4A" . diff-add-change-log-entries-other-window)
    ;; Misc operations.
    ("\C-c\C-a" . diff-apply-hunk)
    ("\C-c\C-e" . diff-ediff-patch)
    ("\C-c\C-n" . diff-restrict-view)
    ("\C-c\C-s" . diff-split-hunk)
    ("\C-c\C-t" . diff-test-hunk)
    ("\C-c\C-r" . diff-reverse-direction)
    ("\C-c\C-u" . diff-context->unified)
    ;; `d' because it duplicates the context :-(  --Stef
    ("\C-c\C-d" . diff-unified->context)
    ("\C-c\C-w" . diff-ignore-whitespace-hunk)
    ;; `l' because it "refreshes" the hunk like C-l refreshes the screen
    ("\C-c\C-l" . diff-refresh-hunk)
    ("\C-c\C-b" . diff-refine-hunk)  ;No reason for `b' :-(
    ("\C-c\C-f" . next-error-follow-minor-mode))
  "Keymap for `diff-mode'.  See also `diff-mode-shared-map'.")
  :type '(choice (string "\e") (string "C-c=") string))
(easy-mmode-defmap diff-minor-mode-map
  `((,diff-minor-mode-prefix . ,diff-mode-shared-map))
  "Keymap for `diff-minor-mode'.  See also `diff-mode-shared-map'.")
(define-minor-mode diff-auto-refine-mode
  "Toggle automatic diff hunk finer highlighting (Diff Auto Refine mode).
  :group 'diff-mode :init-value nil :lighter nil ;; " Auto-Refine"
  (if diff-auto-refine-mode
      (progn
        (customize-set-variable 'diff-refine 'navigation)
        (condition-case-unless-debug nil (diff-refine-hunk) (error nil)))
    (customize-set-variable 'diff-refine nil)))
        (when (re-search-forward regexp-file (point-at-eol 4) t) ; File header.
  (setq-local outline-regexp diff-outline-regexp)
  (if diff-default-read-only
      (setq buffer-read-only t))
  ;; Neat trick from Dave Love to add more bindings in read-only mode:
  (let ((ro-bind (cons 'buffer-read-only diff-mode-shared-map)))
    (add-to-list 'minor-mode-overriding-map-alist ro-bind)
    ;; Turn off this little trick in case the buffer is put in view-mode.
    (add-hook 'view-mode-hook
	      (lambda ()
		(setq minor-mode-overriding-map-alist
		      (delq ro-bind minor-mode-overriding-map-alist)))
	      nil t))
  (save-excursion
    (setq-local diff-buffer-type
                (if (re-search-forward "^diff --git" nil t)
                    'git
                  nil))))
  (setq-local whitespace-style '(face trailing))
    (let* ((beg (or (ignore-errors (diff-beginning-of-hunk))
                    (ignore-errors (diff-hunk-next) (point))
                    max)))
      (while (< beg max)
        (goto-char beg)
        (cl-assert (looking-at diff-hunk-header-re))
        (let ((end
               (save-excursion (diff-end-of-hunk) (point))))
          (cl-assert (< beg end))
          (funcall fun beg end)
          (goto-char end)
          (setq beg (if (looking-at diff-hunk-header-re)
                        end
                      (or (ignore-errors (diff-hunk-next) (point))
                          max))))))))
where DEFUN... is a list of function names found in FILE."
        (pcase-let* ((filename (substring-no-properties (diff-find-file-name)))
    (save-excursion
      ;; FIXME: Include the first space for context-style hunks!
      (while (re-search-forward "^[-+! ]" limit t)
        (let ((spec (alist-get (char-before)
                               '((?+ . (left-fringe diff-fringe-add diff-indicator-added))
                                 (?- . (left-fringe diff-fringe-del diff-indicator-removed))
                                 (?! . (left-fringe diff-fringe-rep diff-indicator-changed))
                                 (?\s . (left-fringe diff-fringe-nul fringe))))))
          (put-text-property (match-beginning 0) (match-end 0) 'display spec))))
      ;; FIXME: Switching between context<->unified leads to messed up
      ;; file headers by cutting the `display' property in chunks!
                 (concat "diff.*\n"
                         "\\(?:\\(?:new file\\|deleted\\).*\n\\)?"
                         "\\(?:index.*\n\\)?"
                         "--- \\(?:" null-device "\\|a/\\(.*\\)\\)\n"
                         "\\+\\+\\+ \\(?:" null-device "\\|b/\\(.*\\)\\)\n"))))
        (put-text-property (match-beginning 0)
                           (or (match-beginning 2) (match-beginning 1))
                           'display (propertize
                                     (cond
                                      ((null (match-beginning 1)) "new file  ")
                                      ((null (match-beginning 2)) "deleted   ")
                                      (t                          "modified  "))
                                     'face '(diff-file-header diff-header)))
        (unless (match-beginning 2)
          (put-text-property (match-end 1) (1- (match-end 0))
                             'display "")))))
                (or (with-demoted-errors (diff-hunk-text hunk (not old) nil))