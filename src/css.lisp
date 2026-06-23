(in-package :lisper)

(defun generate-css ()
  (concatenate 'string
    (cl-css:css
     '(("body"
        :margin 0
        :padding 0
        :font-family "Inter, -apple-system, BlinkMacSystemFont, sans-serif"
        :background-color "#0a0a0a"
        :color "#e0e0e0"
        :line-height "1.6")
       ("a"
        :color "#7c3aed"
        :text-decoration "none"
        :transition "color 0.2s")
       ("a:hover"
        :color "#a855f7")
       (".container"
        :max-width "960px"
        :margin "0 auto"
        :padding "0 20px")
        ("header"
         :padding "40px 0"
         :text-align "center")
        (".logo-container"
         :margin-bottom "20px")
        (".logo-container svg"
         :filter "drop-shadow(0 0 20px rgba(124, 58, 237, 0.3))")
        (".site-note"
         :color "#888"
         :font-size "0.9rem"
         :margin-top "8px")
        (".site-highlight"
         :margin-top "20px"
         :padding "12px 20px"
         :background "linear-gradient(135deg, #1a1a2e, #16213e)"
         :border-left "3px solid #7c3aed"
         :border-radius "8px"
         :color "#e0e0e0"
         :font-size "0.95rem"
         :font-weight 500)
        (".site-badge"
         :display "inline-flex"
         :align-items "center"
         :gap "10px"
         :margin-top "20px"
         :padding "10px 18px"
         :background-color "#111"
         :border "1px solid #2a2a3e"
         :border-radius "24px"
         :color "#ccc"
         :font-size "0.85rem")
        (".site-badge strong"
         :color "#7c3aed")
        (".status-site"
         :font-size "0.75rem"
         :padding "2px 8px"
         :border-radius "4px"
         :font-weight 600
         :vertical-align "middle"
         :background-color "#0d9488"
         :color "#ffffff")
       ("h1"
        :font-size "2.5rem"
        :font-weight 700
        :color "#ffffff"
        :margin-bottom "10px")
       ("h1 span"
        :color "#7c3aed")
        (".tagline"
         :font-weight 400
         :color "#888")
       ("main"
        :padding "40px 0")
       (".section"
        :margin-bottom "40px")
       ("h2"
        :font-size "1.5rem"
        :color "#ffffff"
        :margin-bottom "15px")
       ("p"
        :color "#bbb"
        :margin-bottom "15px")
       ("ul"
        :list-style "none"
        :padding 0)
       ("li"
        :margin-bottom "8px"
        :padding-left "20px"
        :position "relative")
       ("li::before"
        :content "\">\""
        :color "#7c3aed"
        :position "absolute"
        :left 0)
       ("footer"
        :padding "30px 0"
        :text-align "center"
        :color "#555"
        :font-size "0.9rem"
        :border-top "1px solid #1a1a1a")
       (".telegram-link"
        :display "inline-block"
        :padding "12px 24px"
        :background-color "#7c3aed"
        :color "#ffffff"
        :border-radius "8px"
        :font-weight 600
        :transition "background-color 0.2s")
       (".telegram-link:hover"
        :background-color "#a855f7"
        :color "#ffffff")
       (".awesome-section"
        :margin-top "20px")
       (".section-sub"
        :color "#888"
        :margin-bottom "25px")
       (".section-sub a"
        :color "#7c3aed")
       (".cat-grid"
        :display "grid"
        :grid-template-columns "repeat(auto-fill, minmax(180px, 1fr))"
        :gap "12px")
       (".cat-card"
        :display "block"
        :padding "16px 20px"
        :background-color "#111111"
        :border "1px solid #1e1e1e"
        :border-radius "12px"
        :color "#ffffff"
        :font-weight 600
        :font-size "0.95rem"
        :text-decoration "none"
        :transition "all 0.25s ease"
        :position "relative"
        :overflow "hidden")
       (".cat-card::before"
        :content "\"\""
        :position "absolute"
        :top 0
        :left 0
        :width "4px"
        :height "100%"
        :background-color "var(--accent)")
       (".cat-card:hover"
        :border-color "#333"
        :background-color "#161616"
        :transform "translateY(-2px)")

        ;; Implementation cards
        (".impl-grid"
         :display "grid"
         :grid-template-columns "repeat(auto-fill, minmax(280px, 1fr))"
         :gap "16px")

        (".impl-card"
         :display "block"
         :padding "20px 24px"
         :background-color "#111111"
         :border "1px solid #1e1e1e"
         :border-radius "12px"
         :color "#ffffff"
         :text-decoration "none"
         :transition "all 0.25s ease")

        (".impl-card h3"
         :font-size "1.2rem"
         :color "#7c3aed"
         :margin-bottom "8px")

        (".impl-card p"
         :font-size "0.9rem"
         :color "#aaa"
         :margin-bottom 0
         :line-height "1.5")

        (".impl-card:hover"
         :border-color "#333"
         :background-color "#161616"
         :transform "translateY(-2px)")

        ;; Resources list
        (".resources-list"
         :list-style "none"
         :padding 0)

        (".resources-list li"
         :margin-bottom "10px"
         :padding-left "20px"
         :position "relative"
         :color "#bbb"
         :font-size "0.95rem")

        (".resources-list li::before"
         :content "\">\""
         :color "#7c3aed"
         :position "absolute"
         :left 0)

        (".resources-list a"
         :color "#7c3aed"
         :text-decoration "none"
         :font-weight 600)

        (".resources-list a:hover"
         :color "#a855f7")

        ;; Status badges
        (".status-new, .status-experimental"
         :font-size "0.75rem"
         :padding "2px 8px"
         :border-radius "4px"
         :font-weight 600
         :vertical-align "middle")

        (".status-new"
         :background-color "#166534"
         :color "#4ade80")

        (".status-experimental"
         :background-color "#713f12"
         :color "#fbbf24")

        ;; Header buttons
        (".header-buttons"
         :display "flex"
         :gap "12px"
         :justify-content "center"
         :margin-top "20px")

        (".try-button"
         :display "inline-block"
         :padding "12px 24px"
         :background-color "#16a34a"
         :color "#ffffff"
         :border-radius "8px"
         :font-weight 600
         :transition "background-color 0.2s"
         :cursor "pointer")

        (".try-button:hover"
         :background-color "#22c55e"
         :color "#ffffff")

        ;; REPL overlay
        (".repl-overlay"
         :position "fixed"
         :top 0
         :left 0
         :right 0
         :bottom 0
         :background "rgba(0, 0, 0, 0.85)"
         :z-index 1000
         :display "flex"
         :align-items "center"
         :justify-content "center"
         :opacity 0
         :pointer-events "none"
         :transition "opacity 0.3s ease")

        (".repl-overlay.active"
         :opacity 1
         :pointer-events "auto")

        (".repl-modal"
         :width "90%"
         :max-width "720px"
         :height "70vh"
         :max-height "500px"
         :background "#0d0d0d"
         :border "1px solid #2a2a2a"
         :border-radius "12px"
         :display "flex"
         :flex-direction "column"
         :overflow "hidden"
         :box-shadow "0 25px 50px rgba(0, 0, 0, 0.5)")

        (".repl-header"
         :padding "10px 16px"
         :background "#111"
         :border-bottom "1px solid #2a2a2a"
         :display "flex"
         :justify-content "space-between"
         :align-items "center")

        (".repl-header span"
         :color "#7c3aed"
         :font-weight 600
         :font-size "0.95rem")

        (".repl-close"
         :background "none"
         :border "none"
         :color "#666"
         :font-size "1.4rem"
         :cursor "pointer"
         :padding "0 4px"
         :line-height 1
         :transition "color 0.2s")

        (".repl-close:hover"
         :color "#fff")

        (".repl-console"
         :flex 1
         :overflow-y "auto"
         :padding "12px 16px"
         :font-family "'Fira Code', 'JetBrains Mono', 'Cascadia Code', monospace"
         :font-size "13px"
         :line-height "1.6"
         :color "#d4d4d4"
         :background "#0d0d0d")

        (".repl-line"
         :padding 0
         :margin 0
         :white-space "pre-wrap"
         :word-break "break-all")

        (".repl-input-line"
         :display "flex"
         :align-items "center"
         :gap "8px")

        (".repl-prompt-label"
         :color "#7c3aed"
         :font-weight 600
         :white-space "nowrap"
         :flex-shrink 0)

        (".repl-input"
         :flex 1
         :background "transparent"
         :border "none"
         :color "#d4d4d4"
         :font-family "'Fira Code', 'JetBrains Mono', monospace"
         :font-size "13px"
         :outline "none"
         :caret-color "#7c3aed"
         :padding "2px 0"
         :margin 0)

        (".repl-history"
         :color "#888")

        (".repl-result"
         :color "#d4d4d4")

        (".repl-error"
         :color "#ef4444")

        (".repl-status"
         :color "#555"
         :font-style "italic")

        (".repl-credit"
         :color "#555"
         :font-size "12px")

        (".repl-credit a"
         :color "#7c3aed"
         :text-decoration "none")

        (".repl-credit a:hover"
         :color "#a855f7")

        ;; Forum styles
        (".forum-link"
         :display "inline-block"
         :padding "12px 24px"
         :background-color "#7c3aed"
         :color "#ffffff"
         :border-radius "8px"
         :font-weight 600
         :transition "background-color 0.2s"
         :text-decoration "none")

        (".forum-link:hover"
         :background-color "#a855f7"
         :color "#ffffff")

        (".forum-actions"
         :margin-bottom "20px")

        (".forum-categories"
         :display "grid"
         :gap "12px"
         :margin-bottom "30px")

        (".forum-cat-card"
         :display "block"
         :padding "20px 24px"
         :background-color "#111111"
         :border "1px solid #1e1e1e"
         :border-radius "12px"
         :text-decoration "none"
         :transition "all 0.25s ease")

        (".forum-cat-card:hover"
         :border-color "#333"
         :background-color "#161616"
         :transform "translateY(-2px)")

        (".forum-cat-link"
         :text-decoration "none"
         :color "inherit")

        (".forum-cat-link h3"
         :font-size "1.1rem"
         :color "#7c3aed"
         :margin-bottom "6px")

        (".forum-cat-link p"
         :font-size "0.9rem"
         :color "#aaa"
         :margin-bottom "6px")

        (".forum-cat-count"
         :font-size "0.8rem"
         :color "#666")

        (".topic-list"
         :display "grid"
         :gap "8px")

        (".topic-row"
         :padding "12px 16px"
         :background-color "#111111"
         :border "1px solid #1e1e1e"
         :border-radius "8px"
         :transition "all 0.2s ease")

        (".topic-row:hover"
         :border-color "#333"
         :background-color "#161616")

        (".topic-link"
         :display "flex"
         :justify-content "space-between"
         :align-items "center"
         :text-decoration "none"
         :color "inherit"
         :gap "12px")

        (".topic-title"
         :color "#e0e0e0"
         :font-weight 500)

        (".topic-meta"
         :color "#666"
         :font-size "0.85rem"
         :white-space "nowrap")

        (".post-list"
         :display "grid"
         :gap "12px"
         :margin-bottom "20px")

        (".post-card"
         :padding "16px 20px"
         :background-color "#111111"
         :border "1px solid #1e1e1e"
         :border-radius "12px")

        (".post-header"
         :display "flex"
         :align-items "center"
         :gap "10px"
         :margin-bottom "10px")

        (".post-author"
         :color "#7c3aed"
         :font-weight 600)

        (".role-badge"
         :font-size "0.7rem"
         :padding "2px 8px"
         :border-radius "4px"
         :font-weight 600)

        (".role-admin"
         :background-color "#7f1d1d"
         :color "#fca5a5")

        (".role-moderator"
         :background-color "#1e3a5f"
         :color "#93c5fd")

        (".post-date"
         :color "#555"
         :font-size "0.85rem")

        (".post-body"
         :color "#d4d4d4"
         :line-height "1.6"
         :white-space "pre-wrap")

        (".post-actions"
         :margin-top "10px"
         :padding-top "10px"
         :border-top "1px solid #1e1e1e")

        (".delete-btn"
         :background "none"
         :border "1px solid #555"
         :color "#888"
         :padding "4px 12px"
         :border-radius "4px"
         :font-size "0.8rem"
         :cursor "pointer"
         :transition "all 0.2s")

        (".delete-btn:hover"
         :border-color "#ef4444"
         :color "#ef4444")

        (".post-form-section"
         :margin-top "20px")

        (".post-textarea"
         :width "100%"
         :min-height "120px"
         :padding "12px 16px"
         :background-color "#111111"
         :border "1px solid #1e1e1e"
         :border-radius "8px"
         :color "#d4d4d4"
         :font-family "inherit"
         :font-size "0.95rem"
         :resize "vertical"
         :margin-bottom "12px"
         :box-sizing "border-box")

        (".post-textarea:focus"
         :outline "none"
         :border-color "#7c3aed")

        (".form-group"
         :margin-bottom "16px")

        (".form-group label"
         :display "block"
         :margin-bottom "6px"
         :color "#ccc"
         :font-weight 500
         :font-size "0.9rem")

        (".form-group input, .form-group select"
         :width "100%"
         :padding "10px 14px"
         :background-color "#111111"
         :border "1px solid #1e1e1e"
         :border-radius "8px"
         :color "#d4d4d4"
         :font-size "0.95rem"
         :box-sizing "border-box")

        (".form-group input:focus, .form-group select:focus"
         :outline "none"
         :border-color "#7c3aed")

        (".back-link"
         :display "inline-block"
         :margin-bottom "15px"
         :color "#7c3aed"
         :text-decoration "none"
         :font-size "0.9rem")

        (".back-link:hover"
         :color "#a855f7")

        (".topic-info"
         :color "#888"
         :font-size "0.85rem"
         :margin-bottom "20px")

        (".empty-state"
         :color "#666"
         :font-style "italic")

        (".forum-cta"
         :text-align "center"
         :margin-top "20px")

        (".auth-section"
         :max-width "400px"
         :margin "0 auto")

        (".auth-section h2"
         :margin-bottom "20px")

        (".auth-error"
         :padding "10px 16px"
         :background-color "#7f1d1d"
         :border "1px solid #991b1b"
         :border-radius "8px"
         :color "#fca5a5"
         :margin-bottom "16px"
         :font-size "0.9rem")

        (".auth-switch"
         :margin-top "16px"
         :color "#888"
         :font-size "0.9rem")

        (".auth-switch a"
         :color "#7c3aed")

        (".user-info"
         :color "#ccc"
         :font-size "0.9rem")

        (".logout-link"
         :color "#888"
         :font-size "0.85rem"
         :text-decoration "none"
         :margin-left "8px")

        (".logout-link:hover"
         :color "#ef4444")

        (".login-link"
         :color "#888"
         :font-size "0.85rem"
         :text-decoration "none")

        (".login-link:hover"
         :color "#a855f7")

        (".forum-preview .topic-list"
         :max-width "600px")))
    "
@media (max-width: 768px) {
  h1 { font-size: 1.8rem; }
  h2 { font-size: 1.2rem; }
  .container { padding: 0 15px; }
  .cat-grid { grid-template-columns: repeat(2, 1fr); gap: 8px; }
  .cat-card { padding: 12px 14px; font-size: 0.85rem; }
}"))
