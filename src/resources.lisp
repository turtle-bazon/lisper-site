(in-package :lisper)

(defparameter *logo-svg*
  "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>
<svg
   version=\"1.1\"
   viewBox=\"0 0 512 512\"
   id=\"svg2\"
   sodipodi:docname=\"logo.svg\"
   inkscape:version=\"1.4.3 (0d15f75042, 2025-12-25)\"
   xmlns:inkscape=\"http://www.inkscape.org/namespaces/inkscape\"
   xmlns:sodipodi=\"http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd\"
   xmlns=\"http://www.w3.org/2000/svg\"
   xmlns:svg=\"http://www.w3.org/2000/svg\">
  <defs
     id=\"defs2\" />
  <sodipodi:namedview
     id=\"namedview2\"
     pagecolor=\"#ffffff\"
     bordercolor=\"#666666\"
     borderopacity=\"1.0\"
     inkscape:showpageshadow=\"2\"
     inkscape:pageopacity=\"0.0\"
     inkscape:pagecheckerboard=\"0\"
     inkscape:deskcolor=\"#d1d1d1\"
     inkscape:zoom=\"1.5839844\"
     inkscape:cx=\"256\"
     inkscape:cy=\"256\"
     inkscape:window-width=\"1920\"
     inkscape:window-height=\"1008\"
     inkscape:window-x=\"0\"
     inkscape:window-y=\"36\"
     inkscape:window-maximized=\"1\"
     inkscape:current-layer=\"svg2\" />
  <circle
     cx=\"256\"
     cy=\"256\"
     r=\"235\"
     fill=\"#fff\"
     id=\"circle1\"
     style=\"fill:#1a1a2e;fill-opacity:1\" />
  <path
     stroke=\"#000\"
     stroke-width=\"5\"
     d=\"m255.56 20.008c-62.374 0.1169-122.17 24.922-166.3 68.992-92.236 92.091-92.353 241.52-0.2617 333.75 92.09 92.236 241.52 92.353 333.75 0.262 92.236-92.091 92.353-241.52 0.262-333.75-44.377-44.447-104.64-69.371-167.45-69.254zm2.281 1.0059c59.934 0.4846 119.39 23.809 164.46 68.953 91.701 91.845 91.585 240.64-0.259 332.34-45.922 45.851-120.32 45.793-166.17-0.129-45.851-45.922-45.793-120.32 0.129-166.17 46.412-46.339 46.471-121.53 0.13-167.94-37.084-37.141-94.457-46.553-140.66-21.658 42.416-31.541 92.711-45.798 142.37-45.396zm-190.84 130.26h40c9.943 42.147 25.204 79.418 40.75 116.43 15.9-41.326 33.203-81.249 55.25-116.43h40c-48.928 97.364-102.19 164.06-24 250h-40c-47.567-77.243-82.439-147.67-112-250z\"
     id=\"path1\"
     style=\"stroke:#7d3cec;stroke-opacity:1;fill:#7c3bed;fill-opacity:1;stroke-width:10;stroke-dasharray:none\" />
  <path
     d=\"m293 110.72c78.194 85.936 24.928 152.64-24 250h40c22.047-35.179 39.35-75.102 55.25-116.43 15.546 37.01 30.807 74.282 40.75 116.43h40c-29.561-102.33-64.433-172.76-112-250z\"
     id=\"path2\"
     style=\"fill:#7c3bed;fill-opacity:1\" />
</svg>
")

(defparameter *favicon-data-uri*
  (concatenate 'string
               "data:image/svg+xml;base64,"
               "PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiPz4KPHN2ZyB2ZXJzaW9uPSIxLjEiIHZpZXdCb3g9IjAgMCA1MTIgNTEyIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxjaXJjbGUgY3g9IjI1NiIgY3k9IjI1NiIgcj0iMjM1IiBmaWxsPSIjZmZmIi8+CiAgPHBhdGggc3Ryb2tlPSIjMDAwIiBzdHJva2Utd2lkdGg9IjUiIGQ9Im0yNTUuNTYgMjAuMDA4Yy02Mi4zNzQgMC4xMTY5LTEyMi4xNyAyNC45MjItMTY2LjMgNjguOTkyLTkyLjIzNiA5Mi4wOTEtOTIuMzUzIDI0MS41Mi0wLjI2MTcgMzMzLjc1IDkyLjA5IDkyLjIzNiAyNDEuNTIgOTIuMzUzIDMzMy43NSAwLjI2MiA5Mi4yMzYtOTIuMDkxIDkyLjM1My0yNDEuNTIgMC4yNjItMzMzLjc1LTQ0LjM3Ny00NC40NDctMTA0LjY0LTY5LjM3MS0xNjcuNDUtNjkuMjU0em0yLjI4MSAxLjAwNTljNTkuOTM0IDAuNDg0NiAxMTkuMzkgMjMuODA5IDE2NC40NiA2OC45NTMgOTEuNzAxIDkxLjg0NSA5MS41ODUgMjQwLjY0LTAuMjU5IDMzMi4zNC00NS45MjIgNDUuODUxLTEyMC4zMiA0NS43OTMtMTY2LjE3LTAuMTI5LTQ1Ljg1MS00NS45MjItNDUuNzkzLTEyMC4zMiAwLjEyOS0xNjYuMTcgNDYuNDEyLTQ2LjMzOSA0Ni40NzEtMTIxLjUzIDAuMTMtMTY3Ljk0LTM3LjA4NC0zNy4xNDEtOTQuNDU3LTQ2LjU1My0xNDAuNjYtMjEuNjU4IDQyLjQxNi0zMS41NDEgOTIuNzExLTQ1Ljc5OCAxNDIuMzctNDUuMzk2em0tMTkwLjg0IDEzMC4yNmg0MGM5Ljk0MyA0Mi4xNDcgMjUuMjA0IDc5LjQxOCA0MC43NSAxMTYuNDMgMTUuOS00MS4zMjYgMzMuMjAzLTgxLjI0OSA1NS4yNS0xMTYuNDNoNDBjLTQ4LjkyOCA5Ny4zNjQtMTAyLjE5IDE2NC4wNi0yNCAyNTBoLTQwYy00Ny41NjctNzcuMjQzLTgyLjQzOS0xNDcuNjctMTEyLTI1MHoiLz4KICA8cGF0aCBkPSJtMjkzIDExMC43MmM3OC4xOTQgODUuOTM2IDI0LjkyOCAxNTIuNjQtMjQgMjUwaDQwYzIyLjA0Ny0zNS4xNzkgMzkuMzUtNzUuMTAyIDU1LjI1LTExNi40MyAxNS41NDYgMzcuMDEgMzAuODA3IDc0LjI4MiA0MC43NSAxMTYuNDNoNDBjLTI5LjU2MS0xMDIuMzMtNjQuNDMzLTE3Mi43Ni0xMTItMjUweiIvPgo8L3N2Zz4K"))
