;; -*- lexical-binding: t; -*-

(TeX-add-style-hook
 "header"
 (lambda ()
   (TeX-add-to-alist 'LaTeX-provided-package-options
                     '(("scrlayer-scrpage" "")))
   (TeX-run-style-hooks
    "scrlayer-scrpage"))
 :latex)

