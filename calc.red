Red [needs: view]

flags: clear []
    append flags 'modal
    append flags 'popup'

view/flags [backdrop purple
     title "Simple Calculator"
     f: field brown 190x40 font-size 20 font-color white "" return
     style b: button font-size 20 italic font-color red 40x40
     [append f/text face/text]
     b "1"  b "2"  b "3"  b " + "  return
     b "4"  b "5"  b "6"  b " - "  return
     b "7"  b "8"  b "9"  b " * "  return
     b "0"  b "."  b " / "  b "="
     [attempt [ansr: form do f/text append clear f/text ansr]]
] flags