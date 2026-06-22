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
         :color "#fbbf24")))
    "
@media (max-width: 768px) {
  h1 { font-size: 1.8rem; }
  h2 { font-size: 1.2rem; }
  .container { padding: 0 15px; }
  .cat-grid { grid-template-columns: repeat(2, 1fr); gap: 8px; }
  .cat-card { padding: 12px 14px; font-size: 0.85rem; }
}"))
