;; init-company.el --- Initialize company configurations.	-*- lexical-binding: t -*-

;; Copyright (C) 2015-2021 Vincent Zhang

;; Author: Vincent Zhang <seagle0128@gmail.com>
;; URL: https://github.com/seagle0128/.emacs.d

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;;

;;; Commentary:
;;
;; Auto-completion configurations.
;;

;;; Code:

(require 'init-custom)
(require 'init-funcs)

(use-package company
  :diminish
  :defines (company-dabbrev-ignore-case company-dabbrev-downcase)
  :commands company-cancel
  :bind (("M-/" . company-complete)
         ("C-M-i" . company-complete)
         :map company-mode-map
         ("<backtab>" . company-yasnippet)
         :map company-active-map
         ("C-p" . company-select-previous)
         ("C-n" . company-select-next)
         ("<tab>" . company-complete-common-or-cycle)
         ("<backtab>" . my-company-yasnippet)
         :map company-search-map
         ("C-p" . company-select-previous)
         ("C-n" . company-select-next))
  :hook (after-init . global-company-mode)
  :init
  (setq company-tooltip-align-annotations t
        company-tooltip-limit 12
        company-idle-delay 0
        company-echo-delay (if (display-graphic-p) nil 0)
        company-minimum-prefix-length 1
        company-require-match nil
        company-dabbrev-ignore-case nil
        company-dabbrev-downcase nil
        company-global-modes '(not erc-mode message-mode help-mode
                                   gud-mode eshell-mode shell-mode)
        company-backends '((company-capf :with company-yasnippet)
                           (company-dabbrev-code company-keywords company-files)
                           company-dabbrev))

  (defun my-company-yasnippet ()
    "Hide the current completeions and show snippets."
    (interactive)
    (company-cancel)
    (call-interactively 'company-yasnippet))
  :config
  ;; `yasnippet' integration
  (with-no-warnings
    (with-eval-after-load 'yasnippet
      (defun company-backend-with-yas (backend)
        "Add `yasnippet' to company backend."
        (if (and (listp backend) (member 'company-yasnippet backend))
            backend
          (append (if (consp backend) backend (list backend))
                  '(:with company-yasnippet))))

      (defun my-company-enbale-yas (&rest _)
        "Enable `yasnippet' in `company'."
        (setq company-backends (mapcar #'company-backend-with-yas company-backends)))

      (defun my-lsp-fix-company-capf ()
        "Remove redundant `comapny-capf'."
        (setq company-backends
              (remove 'company-backends (remq 'company-capf company-backends))))
      (advice-add #'lsp-completion--enable :after #'my-lsp-fix-company-capf)

      (defun my-company-yasnippet-disable-inline (fn cmd &optional arg &rest _ignore)
        "Enable yasnippet but disable it inline."
        (if (eq cmd  'prefix)
            (when-let ((prefix (funcall fn 'prefix)))
              (unless (memq (char-before (- (point) (length prefix)))
                            '(?. ?< ?> ?\( ?\) ?\[ ?{ ?} ?\" ?' ?`))
                prefix))
          (progn
            (when (and (bound-and-true-p lsp-mode)
                       arg (not (get-text-property 0 'yas-annotation-patch arg)))
              (let* ((name (get-text-property 0 'yas-annotation arg))
                     (snip (format "%s (Snippet)" name))
                     (len (length arg)))
                (put-text-property 0 len 'yas-annotation snip arg)
                (put-text-property 0 len 'yas-annotation-patch t arg)))
            (funcall fn cmd  arg))))
      (advice-add #'company-yasnippet :around #'my-company-yasnippet-disable-inline)))

  ;; Better sorting and filtering
  (use-package company-prescient
    :init (company-prescient-mode 1))

  ;; Icons and quickhelp
  (if (display-graphic-p)
      (if emacs/>=26p
          (use-package company-box
            :diminish
            :defines company-box-icons-all-the-icons
            :hook (company-mode . company-box-mode)
            :init (setq company-box-enable-icon centaur-icon
                        company-box-backends-colors nil
                        company-box-doc-delay 0.1)
            :config
            (with-no-warnings
              ;; Prettify icons
              (defun my-company-box-icons--elisp (candidate)
                (when (or (derived-mode-p 'emacs-lisp-mode) (derived-mode-p 'lisp-mode))
                  (let ((sym (intern candidate)))
                    (cond ((fboundp sym) 'Function)
                          ((featurep sym) 'Module)
                          ((facep sym) 'Color)
                          ((boundp sym) 'Variable)
                          ((symbolp sym) 'Text)
                          (t . nil)))))
              (advice-add #'company-box-icons--elisp :override #'my-company-box-icons--elisp)

              ;; Display borders
              (defun my-company-box--display (string on-update)
                "Display the completions."
                (company-box--render-buffer string on-update)

                (let ((frame (company-box--get-frame))
                      (border-color (face-foreground 'font-lock-comment-face nil t)))
                  (unless frame
                    (setq frame (company-box--make-frame))
                    (company-box--set-frame frame))
                  (company-box--compute-frame-position frame)
                  (company-box--move-selection t)
                  (company-box--update-frame-position frame)
                  (unless (frame-visible-p frame)
                    (make-frame-visible frame))
                  (company-box--update-scrollbar frame t)
                  (set-face-background 'internal-border border-color frame)
                  (when (facep 'child-frame-border)
                    (set-face-background 'child-frame-border border-color frame)))
                (with-current-buffer (company-box--get-buffer)
                  (company-box--maybe-move-number (or company-box--last-start 1))))
              (advice-add #'company-box--display :override #'my-company-box--display)

              (setq company-box-doc-frame-parameters '((internal-border-width . 1)
                                                       (left-fringe . 10)
                                                       (right-fringe . 10)))

              (defun my-company-box-doc--make-buffer (object)
                (let* ((buffer-list-update-hook nil)
                       (inhibit-modification-hooks t)
                       (string (cond ((stringp object) object)
                                     ((bufferp object) (with-current-buffer object (buffer-string))))))
                  (when (and string (> (length (string-trim string)) 0))
                    (with-current-buffer (company-box--get-buffer "doc")
                      (erase-buffer)
                      (insert (propertize "\n" 'face '(:height 0.5)))
                      (insert string)
                      (insert (propertize "\n\n" 'face '(:height 0.5)))

                      ;; handle hr lines of markdown
                      ;; @see `lsp-ui-doc--handle-hr-lines'
                      (let (bolp next before after)
                        (goto-char 1)
                        (while (setq next (next-single-property-change (or next 1) 'markdown-hr))
                          (when (get-text-property next 'markdown-hr)
                            (goto-char next)
                            (setq bolp (bolp)
                                  before (char-before))
                            (delete-region (point) (save-excursion (forward-visible-line 1) (point)))
                            (setq after (char-after (1+ (point))))
                            (insert
                             (concat
                              (and bolp (not (equal before ?\n)) "\n")
                              (propertize (make-string (string-width string) ?─) 'face 'font-lock-comment-face)
                              (and (not (equal after ?\n)) "\n"))))))

                      (setq mode-line-format nil
                            display-line-numbers nil
                            header-line-format nil
                            show-trailing-whitespace nil
                            cursor-in-non-selected-windows nil)
                      (current-buffer)))))
              (advice-add #'company-box-doc--make-buffer :override #'my-company-box-doc--make-buffer)

              (defun my-company-box-doc--show (selection frame)
                (cl-letf (((symbol-function 'completing-read) #'company-box-completing-read)
                          (window-configuration-change-hook nil)
                          (inhibit-redisplay t)
                          (display-buffer-alist nil)
                          (buffer-list-update-hook nil))
                  (-when-let* ((valid-state (and (eq (selected-frame) frame)
                                                 company-box--bottom
                                                 company-selection
                                                 (company-box--get-frame)
                                                 (frame-visible-p (company-box--get-frame))))
                               (candidate (nth selection company-candidates))
                               (doc (or (company-call-backend 'quickhelp-string candidate)
                                        (company-box-doc--fetch-doc-buffer candidate)))
                               (doc (company-box-doc--make-buffer doc)))
                    (let ((frame (frame-local-getq company-box-doc-frame))
                          (border-color (face-foreground 'font-lock-comment-face nil t)))
                      (unless (frame-live-p frame)
                        (setq frame (company-box-doc--make-frame doc))
                        (frame-local-setq company-box-doc-frame frame))
                      (set-face-background 'internal-border border-color frame)
                      (when (facep 'child-frame-border)
                        (set-face-background 'child-frame-border border-color frame))
                      (company-box-doc--set-frame-position frame)
                      (unless (frame-visible-p frame)
                        (make-frame-visible frame))))))
              (advice-add #'company-box-doc--show :override #'my-company-box-doc--show)

              (defun my-company-box-doc--set-frame-position (frame)
                (-let* ((frame-resize-pixelwise t)

                        (box-frame (company-box--get-frame))
                        (box-position (frame-position box-frame))
                        (box-width (frame-pixel-width box-frame))
                        (box-height (frame-pixel-height box-frame))
                        (box-border-width (frame-border-width box-frame))

                        (window (frame-root-window frame))
                        ((text-width . text-height) (window-text-pixel-size window nil nil
                                                                            (- (frame-pixel-width) 50)
                                                                            (- (frame-pixel-height) 50)))
                        (border-width (or (alist-get 'internal-border-width company-box-doc-frame-parameters) 0))

                        (x (- (+ (car box-position) box-width) border-width))
                        (space-right (- (frame-pixel-width) x))
                        (space-left (car box-position))
                        (fringe-left (or (alist-get 'left-fringe company-box-doc-frame-parameters) 0))
                        (fringe-right (or (alist-get 'right-fringe company-box-doc-frame-parameters) 0))
                        (width (+ text-width border-width fringe-left fringe-right))
                        (x (or (and (> width space-right)
                                    (> space-left width)
                                    (- space-left width))
                               x))

                        (y (cdr box-position))
                        (bottom (+ company-box--bottom (window-pixel-top) (frame-border-width)))
                        (height (+ text-height (* 2 border-width)))
                        (y (if (> (+ y height) bottom)
                               (- (+ y box-height) height)
                             y)))
                  (set-frame-position frame (max x 0) (max y 0))
                  (set-frame-size frame text-width text-height t)))
              (advice-add #'company-box-doc--set-frame-position :override #'my-company-box-doc--set-frame-position)

              (when (icons-displayable-p)
                (setq company-box-icons-all-the-icons
                      `((Unknown . ,(all-the-icons-material "find_in_page" :height 1.0 :v-adjust -0.2))
                        (Text . ,(all-the-icons-faicon "text-width" :height 1.0 :v-adjust -0.02))
                        (Method . ,(all-the-icons-faicon "cube" :height 1.0 :v-adjust -0.02 :face 'all-the-icons-purple))
                        (Function . ,(all-the-icons-faicon "cube" :height 1.0 :v-adjust -0.02 :face 'all-the-icons-purple))
                        (Constructor . ,(all-the-icons-faicon "cube" :height 1.0 :v-adjust -0.02 :face 'all-the-icons-purple))
                        (Field . ,(all-the-icons-octicon "tag" :height 1.1 :v-adjust 0 :face 'all-the-icons-lblue))
                        (Variable . ,(all-the-icons-octicon "tag" :height 1.1 :v-adjust 0 :face 'all-the-icons-lblue))
                        (Class . ,(all-the-icons-material "settings_input_component" :height 1.0 :v-adjust -0.2 :face 'all-the-icons-orange))
                        (Interface . ,(all-the-icons-material "share" :height 1.0 :v-adjust -0.2 :face 'all-the-icons-lblue))
                        (Module . ,(all-the-icons-material "view_module" :height 1.0 :v-adjust -0.2 :face 'all-the-icons-lblue))
                        (Property . ,(all-the-icons-faicon "wrench" :height 1.0 :v-adjust -0.02))
                        (Unit . ,(all-the-icons-material "settings_system_daydream" :height 1.0 :v-adjust -0.2))
                        (Value . ,(all-the-icons-material "format_align_right" :height 1.0 :v-adjust -0.2 :face 'all-the-icons-lblue))
                        (Enum . ,(all-the-icons-material "storage" :height 1.0 :v-adjust -0.2 :face 'all-the-icons-orange))
                        (Keyword . ,(all-the-icons-material "filter_center_focus" :height 1.0 :v-adjust -0.2))
                        (Snippet . ,(all-the-icons-material "format_align_center" :height 1.0 :v-adjust -0.2))
                        (Color . ,(all-the-icons-material "palette" :height 1.0 :v-adjust -0.2))
                        (File . ,(all-the-icons-faicon "file-o" :height 1.0 :v-adjust -0.02))
                        (Reference . ,(all-the-icons-material "collections_bookmark" :height 1.0 :v-adjust -0.2))
                        (Folder . ,(all-the-icons-faicon "folder-open" :height 1.0 :v-adjust -0.02))
                        (EnumMember . ,(all-the-icons-material "format_align_right" :height 1.0 :v-adjust -0.2))
                        (Constant . ,(all-the-icons-faicon "square-o" :height 1.0 :v-adjust -0.1))
                        (Struct . ,(all-the-icons-material "settings_input_component" :height 1.0 :v-adjust -0.2 :face 'all-the-icons-orange))
                        (Event . ,(all-the-icons-octicon "zap" :height 1.0 :v-adjust 0 :face 'all-the-icons-orange))
                        (Operator . ,(all-the-icons-material "control_point" :height 1.0 :v-adjust -0.2))
                        (TypeParameter . ,(all-the-icons-faicon "arrows" :height 1.0 :v-adjust -0.02))
                        (Template . ,(all-the-icons-material "format_align_left" :height 1.0 :v-adjust -0.2)))
                      company-box-icons-alist 'company-box-icons-all-the-icons))))

        ;; Popup documentation for completion candidates
        (use-package company-quickhelp
          :defines company-quickhelp-delay
          :bind (:map company-active-map
                 ([remap company-show-doc-buffer] . company-quickhelp-manual-begin))
          :hook (global-company-mode . company-quickhelp-mode)
          :init (setq company-quickhelp-delay 0.3)))

    ;; Display documentation for completion candidates in terminal
    (use-package company-quickhelp-terminal
      :defines company-quickhelp-delay
      :bind (:map company-active-map
             ([remap company-show-doc-buffer] . company-quickhelp-manual-begin))
      :hook ((global-company-mode . company-quickhelp-mode)
             (company-quickhelp-mode  . company-quickhelp-terminal-mode))
      :init (setq company-quickhelp-delay 0.3))))

(provide 'init-company)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; init-company.el ends here
