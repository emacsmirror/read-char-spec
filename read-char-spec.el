;;; read-char-spec.el --- Generalized `y-or-n-p'.

;; Copyright (C) 2009  Edward O'Connor

;; Author: Edward O'Connor <hober0@gmail.com>
;; Keywords: convenience
;; Version: 1.0.0

;; This file is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation; either version 3, or (at your option) any
;; later version.

;; This file is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING. If not, write to the Free
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
;; MA 02110-1301, USA.

;;; Commentary:

;; Provides a generalization of the `y-or-n-p' UI for when you have
;; other possible answers. `read-char-spec' is to `read-char' as
;; `format-spec' is to `format'. Here's how you would re-implement
;; `y-or-n-p' with `read-char-spec':
;;
;; (defun example-y-or-n-p (prompt)
;;   "Copy of `y-or-n-p', as an example use of `read-char-spec'.
;; PROMPT is as for `y-or-n-p'."
;;   (read-char-spec prompt '((?y t "Answer in the affirmative")
;;                            (?n nil "Answer in the negative"))))
;;
;; Compared to using `interactive's "c" spec, I think the programmatic
;; interface for `read-char-spec' is simpler, it keeps prompting until
;; you really type one of the characters in the spec, and it provides
;; for interactive help for the user (by typing "?").

;;; History:
;; 2009-06-17: Initial version, inspired by a conversation with ngirard
;;             in #emacs.

;;; Code:

(defun read-char-spec (prompt specification &optional inherit-input-method
			      seconds initial-help help-text buffer-name)
  "Ask the user a question with multiple possible answers.
No confirmation of the answer is requested; a single character is
enough.

PROMPT is the string to display to ask the question. It should
end in a space; `read-char-spec' adds help text to the end of it.

SPECIFICATION is a list of key specs, each of the form (KEY VALUE
HELP-TEXT).

Arguments INHERIT-INPUT-METHOD and SECONDS are as in `read-char',
which see.

If optional INITIAL-HELP is non-nil display a help buffer,
otherwise that buffer is only shown when the user requests so.

If optional BUFFER-NAME is non-nil display help in a buffer with
that name, otherwise a generic buffer is used."
  (let* ((spec-with-help
          (append (unless initial-help
		    (list (list ?? read-char-spec-help-cmd
				"Get help")))
                  specification))
         (keys (mapconcat (lambda (cell)
                            (read-char-spec-format-key (car cell)))
                          specification
                          ", "))
         (prompt-with-keys (format "%s (%s%s) "
                                   prompt keys
				   (if initial-help "" ", or ? for help")))
         char-read
	 (buffer (get-buffer-create (or buffer-name
					" *read-char-spec*")))
         (current read-char-spec-not-found)
	 (window-configuration (current-window-configuration)))
    (unless help-text
      (setq help-text (princ (format "Help for \"%s\":"
				     (comment-string-strip prompt t t)))))
    ;; Loop until the user types a char actually in `specification'
    (unwind-protect
	(while (eq current read-char-spec-not-found)
	  (when initial-help
	    (read-char-spec-generate-help help-text specification buffer))

	  (setq char-read (read-char-exclusive prompt-with-keys))

	  (let ((entry (assoc char-read spec-with-help)))
	    (when entry
	      (setq current (cadr entry))))

	  ;; Provide help when requested
	  (when (eq current read-char-spec-help-cmd)
	    (read-char-spec-generate-help help-text specification buffer)
	    (setq current read-char-spec-not-found))

	  (setq prompt-with-keys
		(format "Please answer %s. %s "
			keys prompt-with-keys)))
      (kill-buffer buffer)
      (set-window-configuration window-configuration))
    current))

;;; There be dragons here

(defconst read-char-spec-not-found
  (make-symbol "read-char-spec-not-found")
  "Dummy value for when user types character not in the spec provided.")
(defconst read-char-spec-help-cmd
  (make-symbol "read-char-spec-help-cmd")
  "Dummy value for when user types `?' to produce help.")

(autoload 'edmacro-format-keys "edmacro")
(autoload 'comment-string-strip "newcomment")

(defun read-char-spec-format-key (key)
  "Format KEY like input for the `kbd' macro."
  (edmacro-format-keys (vector key)))

(defun read-char-spec-generate-help (help-text specification buffer)
  "Generate help text for PROMPT, based on SPECIFICATION."
  (with-output-to-temp-buffer buffer
    (help-setup-xref (list #'read-char-spec) nil)
    (princ help-text)
    (princ "\n\n")
    (princ (mapconcat (lambda (cell)
                        (format "%s - %s"
                                (read-char-spec-format-key
                                 (car cell))
                                (caddr cell)))
                      specification "\n"))
    (princ "\n\n")
    (help-print-return-message)))

(provide 'read-char-spec)
;;; read-char-spec.el ends here
