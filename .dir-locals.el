;; make eglot respect `.merlin' file

((tuareg-mode
  (eval . (with-eval-after-load 'eglot
            (add-to-list 'eglot-server-programs
                         '(tuareg-mode . ("ocamllsp" "--fallback-read-dot-merlin")))))))
