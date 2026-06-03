;;; $DOOMDIR/modules/tools/pomodoro/config.el -*- lexical-binding: t; -*-

;; ── C 动态模块路径 ─────────────────────────────────────────────
(defvar my/cnotify-so (expand-file-name "c-modules/cnotify-module.so" doom-user-dir)
  "cnotify 模块的 .so 文件路径。")
(defvar my/random-so (expand-file-name "c-modules/random.so" doom-user-dir)
  "random 模块的 .so 文件路径。")

;; ─── cnotify 惰性加载 ──────────────────────────────────────────────
(defun my/cnotify--ensure ()
  (unless (featurep 'cnotify-module)
    (module-load my/cnotify-so)))

(defun my/random--ensure ()
  (unless (featurep 'random-module)
    (module-load my/random-so)))

;; ─── 番茄钟日志 ────────────────────────────────────────────────────────
(defvar my/pomodoro-log-file
  (expand-file-name "pomodoro.eld" doom-user-dir)
  "已完成番茄钟周期的 Sexp 日志。")

(defvar my/pomodoro-default-task "专注"
  "未在提示中提供时的默认任务名称。")

(defun my/pomodoro-log-read ()
  (when (file-exists-p my/pomodoro-log-file)
    (with-temp-buffer
      (insert-file-contents my/pomodoro-log-file)
      (goto-char (point-min))
      (condition-case nil
          (read (current-buffer))
        (error nil)))))

(defun my/pomodoro-log-write (entry)
  (with-temp-file my/pomodoro-log-file
    (when (file-exists-p my/pomodoro-log-file)
      (insert-file-contents my/pomodoro-log-file))
    (goto-char (point-max))
    (insert (prin1-to-string entry) "\n")))

(defun my/pomodoro-log-entry (task minutes)
  (my/pomodoro-log-write
   `(:time ,(format-time-string "%Y-%m-%d %H:%M")
     :task ,task :work ,minutes :break 5)))

(defun my/pomodoro-show-stats ()
  (interactive)
  (let* ((entries (my/pomodoro-log-read))
         (today (format-time-string "%Y-%m-%d"))
          (week-start
           (let* ((decoded (decode-time))
                  (dow (nth 6 decoded))
                  (mon-day (if (= dow 0) 7 dow)))
             (format-time-string "%Y-%m-%d"
                                (encode-time (nth 0 decoded) (nth 1 decoded) (nth 2 decoded)
                                             (- (nth 3 decoded) (1- mon-day))
                                             (nth 4 decoded) (nth 5 decoded)
                                             (nth 8 decoded)))))
         (today-entries (seq-filter
                         (lambda (e) (string-prefix-p today (plist-get e :time)))
                         entries))
         (week-entries (seq-filter
                        (lambda (e) (not (string< (substring (plist-get e :time) 0 10) week-start)))
                        entries))
         (today-cycles (length today-entries))
         (today-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) today-entries)))
         (week-cycles (length week-entries))
         (week-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) week-entries)))
         (total-cycles (length entries))
         (total-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) entries)))
         (buf (get-buffer-create "*Pomodoro Stats*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "🍅 Pomodoro Statistics\n\n"))
      (insert (format "Today:  %d cycles, %d min\n" today-cycles today-minutes))
      (insert (format "Week:   %d cycles, %d min\n" week-cycles week-minutes))
      (insert (format "Total:  %d cycles, %d min (%.1f hours)\n\n"
                      total-cycles total-minutes (/ total-minutes 60.0)))
      (insert "Recent:\n")
      (dolist (e (reverse (seq-take (reverse entries) 10)))
        (insert (format "  %s  %s  %dmin\n"
                        (plist-get e :time) (plist-get e :task) (plist-get e :work))))
      (special-mode)
      (goto-char (point-min)))
    (switch-to-buffer buf)))

;; ─── 番茄钟追踪（阶段转换）────────────────────────────────
(defvar my/pomodoro--prev-phase 0)
(defvar my/pomodoro--current-task nil)
(defvar my/pomodoro--current-work-min 25)

(defun my/pomodoro-start (&optional task work-min break-min)
  (interactive)
  (my/cnotify--ensure)
  (let ((tname (or task
                   (let ((s (read-string "Task: " nil nil my/pomodoro-default-task)))
                     (if (string= s "") my/pomodoro-default-task s))))
        (w (or work-min 25))
        (b (or break-min 5)))
    (setq my/pomodoro--current-task tname
          my/pomodoro--current-work-min w
          my/pomodoro--prev-phase 0)
    (cnotify-pomodoro-start w b)
    (my/cnotify-start-poll)
    (message "🍅 %s — %d min" tname w)))

(defun my/pomodoro-stop ()
  (interactive)
  (my/cnotify--ensure)
  (cnotify-pomodoro-stop)
  (setq my/pomodoro--prev-phase 0)
  (my/cnotify-refresh)
  (message "🍅 Pomodoro stopped — not logged"))

(defun my/timer-start (minutes &optional message)
  (interactive "nMinutes: \nsMessage: ")
  (my/cnotify--ensure)
  (cnotify-timer-start (* minutes 60) (or message "Timer finished"))
  (my/cnotify-start-poll))

(defun my/timer-stop ()
  (interactive)
  (my/cnotify--ensure)
  (cnotify-timer-stop)
  (my/cnotify-refresh))

;; ─── 随机密码 ────────────────────────────────────────────
;;;###autoload
(defun my/random-password (&optional length)
  (interactive "P")
  (my/random--ensure)
  (let* ((len (if (numberp length) length 24))
         (pw (random-password len)))
    (kill-new pw)
    (message "🔑 密码（%d 字符）已复制到剪贴板" len)))

;; ─── 模式行：计时器/番茄钟倒计时 ───────────────────────
(defvar my/cnotify-indicator nil)
(defvar my/cnotify-update-timer nil)

(defun my/cnotify-refresh ()
  (my/cnotify--ensure)
  (when (cnotify-poll-action)
    (select-frame-set-input-focus (selected-frame)))

  (pcase-let ((`(,remaining . ,phase) (cnotify-status)))
    (when (and (= my/pomodoro--prev-phase 1) (= phase 2)
               my/pomodoro--current-task)
      (my/pomodoro-log-entry my/pomodoro--current-task
                             my/pomodoro--current-work-min)
      (message "🍅 %s — %d min ✓" my/pomodoro--current-task
               my/pomodoro--current-work-min))
    (setq my/pomodoro--prev-phase phase)

    (if (and (= remaining 0) (= phase 0))
        (progn (setq my/cnotify-indicator nil)
               (when my/cnotify-update-timer
                 (cancel-timer my/cnotify-update-timer)
                 (setq my/cnotify-update-timer nil)))
      (setq my/cnotify-indicator
            (cond
             ((= phase 1) (format " 🍅 %d:%02d" (/ remaining 60) (% remaining 60)))
             ((= phase 2) (format " ☕ %d:%02d" (/ remaining 60) (% remaining 60)))
             (t           (format " ⏱ %d:%02d" (/ remaining 60) (% remaining 60))))))
    (force-mode-line-update)))

(defun my/cnotify-start-poll ()
  (my/cnotify-refresh)
  (unless my/cnotify-update-timer
    (setq my/cnotify-update-timer (run-with-timer 1 1 #'my/cnotify-refresh))))

(add-to-list 'mode-line-misc-info '("" my/cnotify-indicator ""))

;; ─── 绑定 ────────────────────────────────────────────────────
(map! :leader
      (:prefix-map ("r t" . "Tools")
       :desc "Start timer"              "t" #'my/timer-start
       :desc "Stop timer"               "T" #'my/timer-stop
       :desc "Start pomodoro"           "s" #'my/pomodoro-start
       :desc "Stop pomodoro"            "S" #'my/pomodoro-stop
       :desc "Pomodoro stats"           "v" #'my/pomodoro-show-stats))
