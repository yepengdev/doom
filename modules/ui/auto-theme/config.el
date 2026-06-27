;;; $DOOMDIR/modules/ui/auto-theme/config.el -*- lexical-binding: t; -*-
;;;
;;; 日/夜主题自动切换 — 根据地理位置计算日出日落时间，在
;;; doom-one-light（日间）和 doom-tokyo-night（夜间）之间切换。
;;;
;;; 使用 NOAA 近似算法计算日出日落，精度 ~2 分钟（中纬度）。
;;; 无 Emacs calendar/solar 依赖，纯浮点数学，无全局状态。
;;; 结果按天缓存，每天首次检查触发重算，之后为零开销比较。
;;;
;;; 实时更新（无需重启）：
;;;   M-x my/theme-set-location — 修改位置，立即刷新缓存和主题

;; ─── 外部声明 ────────────────────────────────────────────────────────
;; 以下变量/函数由 Doom 框架在加载本模块前定义。

(defvar doom-theme)
(declare-function doom/reload-theme "doom-lib")

;; ─── 变量 ────────────────────────────────────────────────────────────

(defvar my/theme-day 'doom-one-light
  "日间主题符号。")

(defvar my/theme-night 'doom-tokyo-night
  "夜间主题符号。")

(defvar my/theme-location '("Hangzhou" 30.2741 120.1551)
  "当前地理位置：(NAME LATITUDE LONGITUDE)
LATITUDE: 北正南负（度）。LONGITUDE: 东正西负（度）。
交互式修改：M-x my/theme-set-location")

;; ─── 日出日落计算（NOAA 近似） ──────────────────────────────────────
;; 纯数学，无外部依赖。精度 ~2 分钟，对主题切换足够。

(defun my/theme--sun-times (&optional date)
  "返回 DATE（默认为现在）的 (日出时 . 日落时)，本地浮点小时。
极夜返回 (nil . nil)，极昼返回 (0 . 24)。"
  (let* ((lat (nth 1 my/theme-location))
         (lon (nth 2 my/theme-location))
         (time (or date (current-time)))
         (n (string-to-number (format-time-string "%j" time)))
         (tz (/ (float (car (current-time-zone time))) 3600.0))
         ;; 太阳赤纬 (rad)
         (decl (* 0.40928 (sin (* 2 float-pi (/ (- n 81.0) 365.0)))))
         ;; 时角 (rad)
         (lat-rad (* lat (/ float-pi 180.0)))
         (cos-ha (/ (- (sin -0.01454)
                       (* (sin lat-rad) (sin decl)))
                    (* (cos lat-rad) (cos decl)))))
    (cond ((> cos-ha 1.0) (cons nil nil))       ; 极夜
          ((< cos-ha -1.0) (cons 0.0 24.0))     ; 极昼
          (t
           (let* ((ha (acos cos-ha))
                  (ha-hrs (* ha (/ 12.0 float-pi)))
                  (noon (- 12.0 (/ lon 15.0)))
                  (rise (+ noon (- ha-hrs) tz))
                  (set  (+ noon ha-hrs tz)))
             (cons rise set))))))

;; ─── 缓存 ────────────────────────────────────────────────────────────
;; 按 (DATE LAT LON) 三元组无效化，时间随日期时间戳浮点抖动，
;; 通过 decoded 逐字段比较。

(defvar my/theme--cache nil
  "缓存条目：(TIMESTAMP LAT LON RISE SET)，nil 表示未缓存。")

(defun my/theme--same-day-p (a b)
  "A 和 B 是否为同一日历日。"
  (let ((da (decode-time a))
        (db (decode-time b)))
    (and (= (nth 3 da) (nth 3 db))    ; day
         (= (nth 4 da) (nth 4 db))    ; month
         (= (nth 5 da) (nth 5 db))))) ; year

(defun my/theme--refresh (&optional date)
  "刷新缓存。日期和位置均未变时为空操作（O(1) 比较）。"
  (let* ((d (or date (current-time)))
         (lat (nth 1 my/theme-location))
         (lon (nth 2 my/theme-location)))
    (if (and my/theme--cache
             (my/theme--same-day-p (nth 0 my/theme--cache) d)
             (equal (nth 1 my/theme--cache) lat)
             (equal (nth 2 my/theme--cache) lon))
        nil
      (let ((st (my/theme--sun-times d)))
        (setq my/theme--cache (list d lat lon (car st) (cdr st)))))))

(defsubst my/theme--cached-rise ()
  (nth 3 my/theme--cache))

(defsubst my/theme--cached-set ()
  (nth 4 my/theme--cache))

;; ─── 主题决定 ────────────────────────────────────────────────────────

(defun my/theme-for-hour (&optional hour)
  "返回日间或夜间主题符号。HOUR 默认为当前时（0-23）。
纯函数（缓存刷新是记忆化，不影响行为）。"
  (my/theme--refresh)
  (let* ((h (or hour (nth 2 (decode-time))))
         (r (my/theme--cached-rise))
         (s (my/theme--cached-set)))
    (cond ((null r) my/theme-night)                     ; 极夜
          ((= r 0.0) my/theme-day)                      ; 极昼
          ((let ((r2 (mod r 24.0))
                 (s2 (mod s 24.0)))
             (if (< s2 r2)                              ; 跨午夜（e.g. 日出 20:00, 日落 04:00）
                 (or (>= h r2) (< h s2))
               (and (>= h r2) (< h s2))))
           my/theme-day)
          (t my/theme-night))))

(defun my/theme-apply (theme)
  "切换 `doom-theme' 为 THEME 并刷新 UI。"
  (setq doom-theme theme)
  (when (fboundp 'doom/reload-theme)
    (doom/reload-theme)))

(defun my/theme-switch-maybe ()
  "检查时间，必要时切换主题。挂 `doom-switch-frame-hook'。"
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme))))

;; ─── 实时更新 ────────────────────────────────────────────────────────

(defun my/theme-set-location (name lat lon)
  "设置地理位置并立即刷新主题。"
  (interactive
   (list (read-string "位置名称: " (nth 0 my/theme-location))
         (read-number "纬度（北正南负）: " (nth 1 my/theme-location))
         (read-number "经度（东正西负）: " (nth 2 my/theme-location))))
  (setq my/theme-location (list name lat lon)
        my/theme--cache nil)
  (my/theme-apply (my/theme-for-hour))
  (message "主题已切换至 %s（日出日落）" name))

;; ─── 初始化 ──────────────────────────────────────────────────────────

(setq doom-theme (my/theme-for-hour))
(add-hook 'doom-switch-frame-hook #'my/theme-switch-maybe 'append)
