(in-package :lisper)

;;; Versioned, cache-busting URL for /jscl.js. The bundled JSCL runtime
;;; (~2.4MB) is served with Cache-Control: max-age=1y, immutable; the
;;; version query is a SHA-256 of the content, so any JSCL bump produces
;;; a new URL and clients re-download exactly once.

(defun string-replace-all (needle replacement haystack)
  "Replace every occurrence of NEEDLE with REPLACEMENT in HAYSTACK."
  (if (zerop (length needle))
      haystack
      (with-output-to-string (out)
        (loop with start = 0
              for pos = (search needle haystack :start2 start)
              while pos
              do (write-string haystack out :start start :end pos)
                 (write-string replacement out)
                 (setf start (+ pos (length needle)))
              finally (write-string haystack out :start start)))))

(defvar *jscl-cache-key* nil)

(defun jscl-cache-key ()
  "SHA-256 hex of the embedded *jscl-js*; stable for identical content."
  (or *jscl-cache-key*
      (setf *jscl-cache-key*
            (format nil "~{~2,'0x~}"
                    (coerce (ironclad:digest-sequence
                             :sha256 (sb-ext:string-to-octets *jscl-js*))
                            'list)))))

(defun jscl-url ()
  (format nil "/jscl.js?v=~a" (jscl-cache-key)))

(defvar *jscl-bundle-cache-keys* (make-hash-table :test #'equal))

(defun jscl-bundle-cache-key (name)
  "SHA-256 hex of the bundle content for the versioned URL; memoized."
  (or (gethash name *jscl-bundle-cache-keys*)
      (setf (gethash name *jscl-bundle-cache-keys*)
            (let ((src (get-jscl-bundle name)))
              (when src
                (format nil "~{~2,'0x~}"
                        (coerce (ironclad:digest-sequence
                                 :sha256 (sb-ext:string-to-octets src))
                                'list)))))))

(defun jscl-bundle-url (name)
  (let ((key (jscl-bundle-cache-key name)))
    (when key
      (format nil "/jscl-bundle/~a?v=~a" name key))))
