%% Protokolliert beim Übersetzen eines LilyPond-Notensatzes, welche Töne und
%% welche Silben zu welchem Zeitpunkt in welchem Kontext stehen. Daraus liest
%% wiki_underlay.py ab, auf wie vielen Tönen jede Silbe liegt – so, wie
%% LilyPond selbst den Text unterlegt, nicht wie ein nachgebauter Parser es
%% vermuten würde.
%%
%% Ausgabe: events.tsv im Arbeitsverzeichnis, je Zeile
%%   Zeitpunkt  Art  Kontextnummer  Kontextname  Angaben…

#(define underlay-out (open-output-file "events.tsv"))
#(define underlay-count 0)

#(define (underlay-moment context)
   (exact->inexact (ly:moment-main (ly:context-current-moment context))))

#(define (underlay-text value)
   (if (string? value) value (markup->string value)))

#(define (underlay-listener context)
   (set! underlay-count (+ underlay-count 1))
   (let ((number underlay-count))
     (define (line kind . fields)
       (format underlay-out "~a\t~a\t~a\t~a~{\t~a~}\n"
               (underlay-moment context) kind number
               (ly:context-id context) fields)
       (force-output underlay-out))
     (make-engraver
      (listeners
       ((note-event engraver event)
        (line "note"
              (+ 60 (ly:pitch-semitones (ly:event-property event 'pitch)))
              (exact->inexact
               (ly:moment-main
                (ly:duration-length (ly:event-property event 'duration))))))
       ((rest-event engraver event)
        (line "rest"
              (exact->inexact
               (ly:moment-main
                (ly:duration-length (ly:event-property event 'duration))))))
       ((tie-event engraver event) (line "tie"))
       ((lyric-event engraver event)
        (line "lyric"
              (ly:context-property context 'associatedVoice "")
              (underlay-text (ly:event-property event 'text))))
       ((hyphen-event engraver event) (line "hyphen"))))))

\layout {
  \context { \Voice \consists #underlay-listener }
  \context { \Lyrics \consists #underlay-listener }
}
