# Copyright 1999-2018 Gentoo Foundation
# Copyright 2018-2019 Jan Chren (rindeal)
# Distributed under the terms of the GNU General Public License v2

EAPI=7
inherit rindeal

# TODO: revise 4.15.* changes

## github.eclass:
GITHUB_NS="rpm-software-management"
GITHUB_REF="${P}-release"

PYTHON_COMPAT=( python3_{5,6,7} )

##
inherit github

## functions: eautoreconf
inherit autotools

## functions: append-cppflags
inherit flag-o-matic

## variables: PYTHON_DEPS, PYTHON_REQUIRED_USE
inherit python-single-r1

## functions: tc-check-openmp
inherit toolchain-funcs

## functions: prune_libtool_files
inherit ltprune

DESCRIPTION="Red Hat Package Management Utils"
HOMEPAGE_A=(
	"https://rpm.org/"
	"${GITHUB_HOMEPAGE}"
)
LICENSE_A=(
	"|| ("
		"GPL-2"
		"LGPL-2"
	")"
)

SLOT="0"
SRC_URI_A=(
	"${GITHUB_SRC_URI}"
)

KEYWORDS="~amd64 ~arm ~arm64"
IUSE_A=(
	static-libs +shared-libs +largefile

	zstd ndb lmdb nls rpath python plugins
	gnu-ld
	nss +openssl
	archive
	doc
	imaevm caps acl lua dmalloc

	# automagic deps
	+bzip2 +lzma +elf +libdw

	threads
)

# NOTE: do not care about any `AC_PATH_PROG` deps
CDEPEND_A=(
	"sys-libs/zlib:0"
	"bzip2?   ( app-arch/bzip2:0 )"
	"lzma?    ( app-arch/xz-utils:0 )"
	"zstd?    ( app-arch/zstd:0 )"
	"elf?     ( virtual/libelf:0 )"
	"openssl? ( dev-libs/openssl:0 )"
	"nss?     ( dev-libs/nss:0 )"
	"sys-apps/file:0"  # libmagic
	"dev-libs/popt:0"
	"archive? ( app-arch/libarchive )"
	">=sys-libs/db-4.5:*"
	"lmdb?    ( dev-db/lmdb:0 )"
	"python?  ( ${PYTHON_DEPS} )"
	"imaevm?  ( amd64? ( app-crypt/ima-evm-utils:0 ) )"
	"caps?    ( sys-libs/libcap:0 )"
	"acl?     ( virtual/acl )"
	"lua?     ( >=dev-lang/lua-5.2.0:* )"
	"plugins? ( sys-apps/dbus:0 )"
	"dmalloc? ( dev-libs/dmalloc:0 )"

	# some deps not mentioned in configure.ac
	">=dev-lang/perl-5.8.8"
	"virtual/libintl"
	"app-crypt/gnupg:0"

	"threads? ( virtual/openmp:* )"
)
DEPEND_A=( "${CDEPEND_A[@]}"
	"nls? ("
		"sys-devel/gettext"
		"virtual/libiconv"
	")"
	"doc? ( app-doc/doxygen )"
	"virtual/pkgconfig"
)
RDEPEND_A=( "${CDEPEND_A[@]}"
)

REQUIRED_USE_A=(
	"python? ( ${PYTHON_REQUIRED_USE} )"
	"^^ ( openssl nss )"
	"libdw? ( elf )"
)

# Tests are broken. See bug 657500
RESTRICT+=" test"

inherit arrays

src_unpack()
{
	github:src_unpack
}

src_prepare() {
# 	eapply "${FILESDIR}/${PN}-4.11.0-autotools.patch"
	eapply "${FILESDIR}/${PN}-4.8.1-db-path.patch"
	eapply "${FILESDIR}/${PN}-4.9.1.2-libdir.patch"
	eapply_user

	# fix #356769
	rsed -e 's:%{_var}/tmp:/var/tmp:' -i -- macros.in
	# fix #492642
	rsed -e "s:@__PYTHON@:${PYTHON}:" -i -- macros.in

	rsed -e "s/AC_CONFIG_SUBDIRS(db3)/foo=bar/" -i -- configure.ac

	eautoreconf

	# Prevent automake maintainer mode from kicking in (#450448).
# 	touch -r Makefile.am preinstall.am
}

src_configure() {
	append-cppflags -I"${EPREFIX}/usr/include/nss" -I"${EPREFIX}/usr/include/nspr"

	local my_econf_args=(
		### Optional Features:
		$(use_enable static-libs static)
		$(use_enable shared-libs shared)
		$(use_enable largefile)
		$(use_enable zstd)
		$(use_enable ndb)
		$(use_enable lmdb)
		$(use_enable nls)
		$(use_enable rpath)
		$(use_enable python)
		$(use_enable plugins)

		### Optional Packages:
		$(use_with gnu-ld)
		--with-crypto=$(usex openssl{,} $(usex nss{,} ERROR))
		--without-internal-beecrypt
		$(use_with archive)
		$(use_with doc hackingdocs)
		--without-selinux
		$(use_with imaevm)
		$(use_with caps cap)
		$(use_with acl)
		$(use_with lua)
		$(use_with dmalloc)
# 		--with-rundir=RUNDIR

		$(use_enable threads openmp)
	)
	econf "${my_econf_args[@]}"
}

src_install() {
	default

	# fix symlinks to /bin/rpm (#349840)
	for binary in rpmquery rpmverify ; do
		rln -sf rpm "${ED}"/usr/bin/${binary}
	done

	if ! use nls ; then
		# patching Makefile.am in this case would be cumbersome
		rrm -r "${ED}"/usr/share/man/??
	fi

	keepdir /usr/src/rpm/{SRPMS,SPECS,SOURCES,RPMS,BUILD}

	dodoc CREDITS README*
	if use doc ; then
		for docname in hacking librpm ; do
			docinto "html/${docname}"
			dodoc -r "doc/${docname}/html/."
		done
	fi

	prune_libtool_files

	# perl_delete_localpod(): Fix perllocal.pod file collision
	find "${D}" -type f -name perllocal.pod -delete || die
	find "${D}" -depth -mindepth 1 -type d -empty -delete || die
}

pkg_postinst() {
	if [[ -f "${EROOT}"/var/lib/rpm/Packages ]] ; then
		einfo "RPM database found... Rebuilding database (may take a while)..."
		"${EROOT}"/usr/bin/rpmdb --rebuilddb --root="${EROOT}" || die
	else
		einfo "No RPM database found... Creating database..."
		"${EROOT}"/usr/bin/rpmdb --initdb --root="${EROOT}" || die
	fi
}
