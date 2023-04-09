Red [
    Title: ""
]

finalseg: make object! [

    han: charset [#"^(4E00)" - #"^(9FD5)"]
    alpha: charset [#"a" - #"z" #"A" - #"Z"]
    num: charset [#"0" - #"9"]
    alphanum: union alpha num
    non-space: charset [#"+" #"#" #"&" #"." #"_" #"-"]

    han-default: union union han alphanum non-space
    skip-default: charset [#"^^" #"^M" #" "]
    han-cut-all: han
    skip-cut-all: charset [not #"0"-#"9" #"a"-#"z" #"A"-#"Z" #"+" #"#" #"^^" #"^M"]  ;lf: #"^^" cr: #"^M"

    MIN_FLOAT: -3.14e100

    PROB_START: %prob_start.red
    PROB_TRANS: %prob_trans.red
    PROB_EMIT: %prob_emit.red

    status: ['B 'E 'M 'S]

    prev-status: [
        'B ['E 'S]
        'M ['M 'B]
        'S ['S 'E]
        'E ['B 'M]
    ]

    start-p: load PROB_START
    trans-p: load PROB_TRANS
    emit-p: load PROB_EMIT

    viterbi: function [ observed [string!] ][
        weight: copy [ #() ]
        path: make map! []

        foreach state status [
            emit-prob-1: either none? emit-p/(state)/(to string! observed/1) [ MIN_FLOAT ][ emit-p/(state)/(to string! observed/1) ]
            weight/1/(state): start-p/(state) + emit-prob-1
            path/(state): reduce [state]
        ]

        repeat i ((length? observed) - 1) [
            append weight copy #()
            new-path: make map![]
            foreach state status [
                tmp: collect [
                    foreach prev-state prev-status/(state) [
                        keep prev-state
                        keep weight/(i)/(prev-state) + trans-p/(prev-state)/(state) + emit-p/(state)/(to string! observed/(i + 1))
                    ]
                ]

                w: sort/skip/compare/reverse copy tmp 2 2
                weight/(i + 1)/(state): w/2
                new-path/(state): append copy path/(w/1) state
            ]

            path: new-path
        ]

        ; probe weight
        ; probe path

        prob: last weight
        either prob/E > prob/S [
            path/E
        ][
            path/S
        ]
    ]

    cut-block: function [sentence][
        pos-list: viterbi sentence
        len: length? sentence
        begin: nexti: 0
        result: copy []

        result: collect [
            repeat i len [
                char: to string! sentence/(i)
                pos: pos-list/(i)
                switch pos [
                    'B [ begin: i ]
                    'E [ keep copy/part at sentence begin (i - begin + 1)  nexti: i + 1]
                    'S [ keep char nexti: i + 1]
                    'M []
                ]
            ]
        ]

        if nexti < len [
            append result copy at sentence nexti
        ]

        result
    ]

    cut: function [ sentence ][
        blocks: parse sentence [ 
            collect [
                any [
                    keep some han-default | skip
                ]
            ]
        ]

        collect [
            foreach blk blocks [
                if parse blk [ some han ] [
                    foreach word cut-block blk [
                        keep word
                    ]
                ]
            ]
        ]
    ]
]

;test 
; probe finalseg/viterbi "小明硕士毕业于中国科学院计算所" ;should be ['B 'E 'B 'E 'B 'M 'E 'B 'E 'B 'M 'E 'B 'E 'S]
; probe finalseg/cut "小明硕士毕业于中国科学院计算所" ;should be ["小明" "硕士" "毕业于" "中国" "科学院" "计算" "所"]