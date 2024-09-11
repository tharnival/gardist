module Styles exposing (..)

import Css
import Tailwind.Theme exposing (..)
import Tailwind.Utilities exposing (..)


type alias Style =
    List Css.Style


buttonStyle : Style
buttonStyle =
    [ bg_color gray_300
    , border_0
    , rounded_md
    , text_2xl
    , py_2
    , Css.hover [ bg_color gray_600 ]
    , Css.active [ bg_color gray_800 ]
    , Css.disabled [ Css.hover [ bg_color gray_300 ] ]
    ]


textFieldStyle : Style
textFieldStyle =
    [ h_32
    , rounded_md
    , text_2xl
    ]


checkboxStyle : Style
checkboxStyle =
    [ w_4
    , h_4
    ]


expanderStyle : Style
expanderStyle =
    [ w_6
    , h_6
    , text_base
    ]


indentStyle : Style
indentStyle =
    [ py_0
    , px_3
    ]
