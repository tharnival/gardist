module Styles exposing (..)

import Css
import Tailwind.Theme exposing (..)
import Tailwind.Utilities exposing (..)


type alias Style =
    List Css.Style


button : Style
button =
    [ bg_color gray_300
    , border_0
    , rounded_md
    , text_2xl
    , py_2
    , Css.hover [ bg_color gray_600 ]
    , Css.active [ bg_color gray_800 ]
    , Css.disabled [ Css.hover [ bg_color gray_300 ] ]
    ]


text : Style
text =
    [ rounded_md
    , text_2xl
    ]


textField : Style
textField =
    [ h_32
    , rounded_md
    , text_2xl
    ]


checkbox : Style
checkbox =
    [ w_4
    , h_4
    ]


expander : Style
expander =
    [ w_6
    , h_6
    , text_base
    ]


indent : Style
indent =
    [ py_0
    , px_3
    ]
