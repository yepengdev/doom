;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el
(package! eaf
  :recipe (:host github :repo "emacs-eaf/emacs-application-framework"
           :files ("*")
           :post-build (progn
                         (async-shell-command "python install-eaf.py"))))

(package! calctex :recipe (:host github :repo "johnbcoughlin/calctex"
                           :files ("*.el" "calctex/*.el" "calctex-contrib/*.el" "org-calctex/*.el" "vendor")))

(package! org-transclusion :recipe (:host github :repo "nobiot/org-transclusion"))
(package! org-pandoc-import
  :recipe (:host github
           :repo "tecosaur/org-pandoc-import"
           :files ("*.el" "filters" "preprocessors")))

(package! org-modern)

(package! nano-theme
  :recipe (:host github
           :repo "rougier/nano-theme"))
(package! nano-modeline)
(package! nano-vertico
  :recipe (:host github
           :repo "rougier/nano-vertico"))

(package! solo-jazz-theme)

(package! catppuccin-theme)
(package! kaolin-themes)

(package! pyim)
(package! pyim-basedict)

(package! github-theme)
(package! xclip)

(package! image-roll :recipe
  (:host github
   :repo "dalanicolai/image-roll.el"))

(package! ob-mathematica)
(package! wolfram-mode)

(unpin! pdf-tools)
(package! pdf-tools :recipe (:host github :repo "vedang/pdf-tools"))

(package! org-ql
  :recipe (:host github :repo "alphapapa/org-ql"
           :files  (:defaults (:exclude "helm-org-ql.el"))))
(package! org-contrib :recipe (:host github :repo "emacsmirror/org-contrib"))
(package! draft-mode)
(package! empv :recipe (:host github :repo "isamert/empv.el"))
(package! eat)
(package! wc-mode :recipe (:host github :repo "bnbeckwith/wc-mode"))
(package! gemini-cli :recipe (:host github :repo "linchen2chris/gemini-cli.el"))

(package! rainbow-delimiters)
(package! org-download)
(package! org-fragtog)
(package! denote)
(package! alert)
(package! ef-themes)

(package! dslide :recipe (:host github :repo "positron-solutions/dslide"))
(unpin! org-roam)
(package! org-roam-ui)

(package! websocket)

(package! nov.el
  :recipe (:host github :repo "emacs-pe/nov.el"))
(package! justify-kp
  :recipe (:host github :repo "Fuco1/justify-kp")
  )

(package! pdf-view-pagemark)

(package! rime
  :recipe (:host github :repo "DogLooksGood/emacs-rime"))

(package! pdf-view-restore
  :recipe (:host github :repo "007kevin/pdf-view-restore"))
