extends RefCounted
## The imperial banner, drawn as SVG so it stays crisp at any size: a black
## double-headed eagle on gold, with crowned heads, the imperial crown between them,
## sword and orb in its talons and the red-white-red shield on its breast.
## Original artwork for this game, in a 300 x 200 view box.

const GOLD := "#f2c230"
const BLACK := "#141414"
const RED := "#c8102e"


## The eagle alone, centred on (150, 105) of the view box.
static func eagle() -> String:
	# One wing, neck and head; the left side is the same group mirrored.
	var half := """
<path d="M156,84 C172,64 198,50 228,42 C238,39 244,44 239,51 L231,58 L241,61 L233,70 L243,75 L233,84 L240,91 L229,98 L234,106 L221,110 L223,118 L209,117 L205,124 L193,119 C181,112 169,105 158,100 Z" fill="%s"/>
<path d="M170,72 L230,48 M176,82 L234,66 M180,92 L236,84 M184,101 L230,100 M186,108 L218,114 M188,113 L205,120" stroke="%s" stroke-width="1.6" fill="none" stroke-linecap="round"/>
<path d="M152,88 C156,74 160,63 166,55 C170,48 178,46 183,50 C187,52 191,52 196,54 L187,57 C185,60 181,60 178,59 C173,65 168,76 165,90 Z" fill="%s"/>
<path d="M183,50 C188,49 194,51 198,54 L190,57 C188,55 185,54 183,53 Z" fill="%s"/>
<path d="M190,57 L199,61 L192,59 Z" fill="%s"/>
<circle cx="178" cy="52" r="1.6" fill="%s"/>
<path d="M169,49 L170,40 L173.5,45 L176.5,37 L179.5,45 L183,40 L184,49 Z" fill="%s" stroke="%s" stroke-width="0.8"/>
""" % [BLACK, GOLD, BLACK, GOLD, RED, GOLD, GOLD, BLACK]
	var svg := "<g>%s</g><g transform=\"translate(300,0) scale(-1,1)\">%s</g>" % [half, half]
	# Body and fanned tail with gold feather lines.
	svg += """
<ellipse cx="150" cy="106" rx="15" ry="23" fill="%s"/>
<path d="M138,124 L131,151 L140,146 L144,157 L150,148 L156,157 L160,146 L169,151 L162,124 Z" fill="%s"/>
<path d="M144,128 L141,148 M150,128 L150,150 M156,128 L159,148" stroke="%s" stroke-width="1.4" fill="none"/>
""" % [BLACK, BLACK, GOLD]
	# Legs: the right talon holds a sword, the left the imperial orb.
	svg += """
<path d="M157,118 L171,133 L176,131 L174,137 L168,138 L155,124 Z" fill="%s"/>
<path d="M143,118 L129,133 L124,131 L126,137 L132,138 L145,124 Z" fill="%s"/>
<path d="M174,136 L211,92 L214,95 L177,139 Z" fill="#dcdcdc" stroke="%s" stroke-width="0.8"/>
<path d="M168,128 L182,142" stroke="%s" stroke-width="3" stroke-linecap="round"/>
<circle cx="171" cy="141" r="2.4" fill="%s"/>
<circle cx="126" cy="140" r="8" fill="%s" stroke="%s" stroke-width="1.8"/>
<path d="M118,140 L134,140" stroke="%s" stroke-width="1.4"/>
<path d="M126,132 L126,124 M122,127 L130,127" stroke="%s" stroke-width="2" stroke-linecap="round"/>
""" % [BLACK, BLACK, BLACK, GOLD, GOLD, GOLD, BLACK, BLACK, GOLD]
	# Breast shield: red-white-red under a small crown.
	svg += """
<path d="M140,96 L160,96 L160,112 C160,120 155,124 150,128 C145,124 140,120 140,112 Z" fill="%s" stroke="%s" stroke-width="1.4"/>
<rect x="140.7" y="104" width="18.6" height="7" fill="#f4f1ea"/>
<path d="M142,95 L143,88 L146,92 L150,86 L154,92 L157,88 L158,95 Z" fill="%s" stroke="%s" stroke-width="0.7"/>
""" % [RED, GOLD, GOLD, BLACK]
	# The imperial crown above, between the heads.
	svg += """
<path d="M136,47 C136,31 150,25 150,25 C150,25 164,31 164,47 Z" fill="%s" stroke="%s" stroke-width="1"/>
<path d="M141,46 C141,36 150,31 150,31 C150,31 159,36 159,46 Z" fill="%s"/>
<rect x="134" y="45" width="32" height="6" rx="1" fill="%s" stroke="%s" stroke-width="1"/>
<circle cx="140" cy="48" r="1.4" fill="%s"/><circle cx="150" cy="48" r="1.4" fill="#2a6fd6"/><circle cx="160" cy="48" r="1.4" fill="%s"/>
<path d="M150,25 L150,16 M146,19 L154,19" stroke="%s" stroke-width="2.2" stroke-linecap="round"/>
""" % [GOLD, BLACK, RED, GOLD, BLACK, RED, RED, GOLD]
	return svg


## The imperial banner: the eagle on gold inside a black-and-gold border.
static func banner() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200" viewBox="0 0 300 200">
<rect width="300" height="200" fill="%s"/>
<rect x="5" y="5" width="290" height="190" fill="none" stroke="%s" stroke-width="6"/>
<rect x="11" y="11" width="278" height="178" fill="none" stroke="%s" stroke-width="1.5"/>
%s
</svg>""" % [GOLD, BLACK, BLACK, eagle()]


## The Empire's black-over-gold bicolour with the eagle arms in the centre.
static func bicolour() -> String:
	return """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200" viewBox="0 0 300 200">
<rect width="300" height="100" fill="%s"/>
<rect y="100" width="300" height="100" fill="%s"/>
<ellipse cx="150" cy="100" rx="54" ry="64" fill="%s" stroke="%s" stroke-width="3"/>
<g transform="translate(150,100) scale(0.5) translate(-150,-92)">%s</g>
</svg>""" % [BLACK, GOLD, GOLD, BLACK, eagle()]
