Red []

do %finalseg/finalseg.red

han: charset [#"^(4E00)" - #"^(9FD5)"]
alpha: charset [#"a" - #"z" #"A" - #"Z"]
num: charset [#"0" - #"9"]
alphanum: union alpha num
non-space: charset [#"+" #"#" #"&" #"." #"_" #"-"]

han-default: union union han alphanum non-space
skip-default: charset [#"^^" #"^M" #" "]
han-cut-all: han
skip-cut-all: charset [not #"0"-#"9" #"a"-#"z" #"A"-#"Z" #"+" #"#" #"^^" #"^M"]  ;lf: #"^^" cr: #"^M"

DICT_WRITING: copy []
DEFAULT_DICT: NONE
DEFAULT_DICT_NAME: copy "dict.txt"

GLOBAL_FREQ: NONE
total: 0

tokenizer: make object! [
    dictionary: NONE
    user_word_tag_tab: copy []
    initialized: false
    tmp_dir: NONE
    cache_file: %jieba.cache

    get_DAG: function [sentence][
        if none? GLOBAL_FREQ [
            start: now/time
            gen_pfdict DEFAULT_DICT_NAME
            print rejoin ["gen_pfdict:" (now/time - start)]
        ]

        DAG: make map! []
        N: length? sentence
        repeat k N [
            tmplist: copy []
            i: k
            frag: to-string sentence/(k)
            ; print frag

            while [i <= N  and (not none? find GLOBAL_FREQ frag) ][
                if not zero? GLOBAL_FREQ/(frag) [
                    append tmplist i
                ]

                i: i + 1
                frag: copy/part at sentence k (i - k + 1)
            ]

            if (length? tmplist) = 0 [
                append tmplist k
            ]

            DAG/(k): tmplist
        ]

        DAG
    ]

    cut-all: function [sentence][
        dag: self/get_DAG sentence
        ; probe dag

        old-index: -1
        result: copy []
        foreach key keys-of dag [
            list: select dag key
            either ((length? list) = 1) and (key > old-index) [
                append result copy/part at sentence key (list/1 - key + 1)
            ][
                foreach index list [
                    if index > key [
                        append result copy/part at sentence key (index - key + 1)
                        old-index: index
                    ]
                ]
            ]
        ]

        result
    ]

    cut-DAG-NO-HMM: function [ sentence ][
        dag: self/get_DAG sentence
        route: self/calc sentence dag
        ; print route

        x: 1
        N: length? sentence
        buf: copy []
        result: collect [
            while [x < N] [
                y: route/(x)/2 + 1
                L-word: copy/part at sentence x (y - x)
                either (parse L-word [ some alphanum ]) and ((length? L-word) = 1) [
                    append buf L-word
                ][
                    if not empty? buf [
                        keep buf
                        buf: copy []
                    ]
                    ; print rejoin ["L-word: " L-word]
                    keep L-word
                ]
                x: y
            ]

            if  not empty? buf [
                keep buf
                buf: copy []
            ]
        ]

        result
    ]

    cut-DAG: function [sentence][
        dag: self/get_DAG sentence
        route: self/calc sentence dag

        x: 1
        N: length? sentence
        buf: copy ""

        collect [
            while [x < N] [
                y: route/(x)/2 + 1
                L-word: copy/part at sentence x (y - x)

                either y - x = 1 [
                    append buf L-word
                ] [
                    if not empty? buf [
                        either (length? buf) = 1 [
                            keep buf
                            buf: copy ""
                        ] [
                            either none? find GLOBAL_FREQ buf [
                                recognized: finalseg/cut buf
                                foreach t recognized [
                                    keep t
                                ]
                            ] [
                                foreach elem buf [
                                    keep to string! elem
                                ]
                            ]

                            buf: copy ""
                        ]
                    ]

                    keep L-word
                ]

                x: y
            ]

            if not empty? buf [
                case [
                    (length? buf) = 1 [ keep buf ]
                    none? find GLOBAL_FREQ buf []
                ]

                either (length? buf) = 1 [
                    keep buf
                ][
                    either none? find GLOBAL_FREQ buf [
                        recognized = finalseg/cut buf
                        foreach t recognized [
                            keep t
                        ]
                    ][
                        foreach elem buf [
                            keep to string! elem
                        ]
                    ]
                ]
            ]
        ]
    ]

    gen_pfdict: function [dictfilename /extern total GLOBAL_FREQ][
        either exists? cache_file [
            cache: load cache_file
            total: to-integer cache/2
            GLOBAL_FREQ: cache/1
        ][
            lfreq: make map! []
            ltotal: 0
            lines: read/lines to-file dictfilename
            foreach line lines [
                blk: split line space
                word: blk/1
                freq: to-integer blk/2
                lfreq/(word): freq
                ltotal: ltotal + freq
                repeat i length? word [
                    wfrag: take/part copy word i
                    if not lfreq/(wfrag) [
                        lfreq/(wfrag): 0
                    ]
                ]
            ]

            GLOBAL_FREQ: lfreq
            total: ltotal

            write cache_file mold reduce [lfreq ltotal]
        ]
    ]   

    calc: function [sentence [string!] DAG [map!] /extern total GLOBAL_FREQ ][
        N: length? sentence 
        route: make map! reduce [N + 1 0x0]
        logtotal: log-e total

        idx: N
        until [
            tmplist: DAG/(idx)

            candidates: collect [
                foreach i tmplist [
                    rate: GLOBAL_FREQ/(copy/part at sentence idx (i - idx + 1))
                    axis-x:  log-e (either (none? rate) or (rate <= 0) [1][rate] ) - logtotal + route/(i + 1)/1
                    keep (to pair! reduce [axis-x i])
                ]
            ]

            ; probe candidates
            ; probe last sort candidates
            route/(idx): last sort candidates

            idx: idx - 1
            idx <= 0
        ]
        route
    ]
]


cut: function [ 
        {
            The main function that segments an entire sentence that contains
            Chinese characters into separated words.
        }
        sentence "The str(unicode) to be segmented."
        /cut-all "Model type. True for full pattern, False for accurate pattern."
        /no-HMM "Whether to use the Hidden Markov Model."
    ][
    
    either cut-all [
        re_han: han-cut-all
        re_skip: skip-cut-all
    ] [
        re_han: han-default
        re_skip: skip-default
    ]


    cut-block: NONE
    either cut-all [
        cut-block: :tokenizer/cut-all
    ][
        either no-HMM [
            cut-block: :tokenizer/cut-DAG-NO-HMM
        ][
            cut-block: :tokenizer/cut-DAG
        ]
    ]

    blocks: parse sentence [ 
        collect [
            any [
                keep some han-default | skip
            ]
        ]
    ]

    result: copy []
    foreach blk blocks [
        if parse blk [ some re_han] [
            foreach word cut-block blk [
                append result word
            ]
        ]
    ]

    result
]

start: now/time
sentence: "本质上是一个分布式数据库，允许多台服务器协同工作，每台服务器可以运行多个实例"
; sentence: "小明硕士毕业于中国科学院计算所"
probe cut sentence
print rejoin ["cost:" (now/time - start)]

