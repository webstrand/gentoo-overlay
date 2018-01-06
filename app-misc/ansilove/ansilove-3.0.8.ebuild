# Copyright 2018 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit rindeal

## git-hosting.eclass:
GH_RN="github"

## EXPORT_FUNCTIONS: src_unpack
inherit git-hosting
## EXPORT_FUNCTIONS src_prepare src_configure src_compile src_test src_install
inherit cmake-utils

DESCRIPTION="ANSi/ASCII art to PNG converter in C"
HOMEPAGE="https://www.ansilove.org/"
LICENSE="BSD-2"

SLOT="0"

KEYWORDS="~amd64 ~arm ~arm64"
IUSE_A=( )

CDEPEND_A=(
	"media-libs/gd"
)
DEPEND_A=( "${CDEPEND_A[@]}" )
RDEPEND_A=( "${CDEPEND_A[@]}" )

inherit arrays

src_prepare() {
	eapply_user

	sed -r -e "/add_definitions/ s,(-pedantic|-Werror),,g" -i -- CMakeLists.txt || die

	cmake-utils_src_prepare
}
