# GNU Makefile (>= 3.82) for building Caml Light projects
# (c) 2012, 2013 Christian Rinderknecht (rinderknecht@free.fr)
#
# You may freely modify and redistribute, as long as I am credited as
# the original author and the same terms apply to the recipients,
# including no commercial use allowed without permission. Please
# report any error you may find. Consult Makefile.man and
# Makefile.doc, which must be distributed along with this makefile,
# as well as the modified source of [camldep].

# ====================================================================
# General Settings (GNU Make 4.0 recommended)

ifeq (4.1,${MAKE_VERSION})
MAKEFLAGS =-Rrsij -Oline
else
  ifeq (4.0,${MAKE_VERSION})
MAKEFLAGS =-Rrsij -Oline
  else
    ifeq (3.82,${MAKE_VERSION})
MAKEFLAGS =-Rrsi
    else
      ${error Requires GNU Make 3.82 or higher}
    endif
  endif
endif

ifeq (,${MAKECMDGOALS})
${if ${DEBUG},${info No command goals.}}
else 
${if ${DEBUG},${info Command goals: ${MAKECMDGOALS}}}
endif

.ONESHELL:        # One call to the shell per recipe
#.RECIPEPREFIX = > # Use [>] instead of TAB for recipes

# By default, do not infer linking dependencies.

LOG_OBJ := no

# Filtering the sources

# Filtering sources and tags

export MLL       := ${wildcard *.mll}
export LMOD      := ${basename ${MLL}}
export LML       := ${LMOD:%=%.ml}
export MLY       := ${wildcard *.mly}
export YMOD      := ${basename ${MLY}}
export YMLI      := ${YMOD:%=%.mli}
export YML       := ${YMOD:%=%.ml}
export MLI       := ${wildcard *.mli}
export INTF      := ${sort ${YMOD} ${basename ${MLI}}}
export ML        := ${wildcard *.ml}
export IMPL      := ${sort ${LMOD} ${YMOD} ${basename ${ML}}}

export INTF_ONLY := ${filter-out ${IMPL},${INTF}}
export IMPL_ONLY := ${filter-out ${INTF},${IMPL}}
export MOD       := ${filter ${INTF},${IMPL}}

export TAGS       := ${wildcard .*.tag}
export MLY_TAGGED := ${filter ${MLY}, \
                        ${patsubst .%.mly.tag,%.mly,${TAGS}}}
export MLL_TAGGED := ${filter ${MLL}, \
                        ${patsubst .%.mll.tag,%.mll,${TAGS}}}

Makefile Makefile.cfg: ;

sinclude Makefile.cfg

ifdef BIN
  ifeq (,${filter ${BIN},${IMPL}})
    ${error Cannot find ${BIN}.ml or ${BIN}.mll or ${BIN}.mly}
  endif
  .DEFAULT_GOAL := ${BIN}
else
  ifeq (,${MAKECMDGOALS})
    ${error Set variable BIN in Makefile.cfg}
  else
    ifneq (,${filter byte nat opt,${MAKECMDGOALS}})
      ${error Set variable BIN in Makefile.cfg}
    endif
  endif
endif

ifeq (,${MAKECMDGOALS})
BUILD := ${.DEFAULT_GOAL}
else
BUILD := ${filter %.zi %.zo ${BIN} ${OBJDIR}/${BIN}, ${MAKECMDGOALS}}
endif

# Directory for object files and executables

ifndef OBJDIR
export OBJDIR := _${shell arch}
endif

ifeq (0-,${MAKELEVEL}-${MAKE_RESTARTS})
  ifneq (,${BUILD})
  ${shell mkdir -p ${OBJDIR}}
  endif
endif

vpath %.zi   ${OBJDIR}
vpath %.zo   ${OBJDIR}
vpath ${BIN} ${OBJDIR}

# Verbosity and debugging modes

export VERB DEBUG
ifeq (yes,${DEBUG})
override VERB := yes
endif

# Checking system configuration (for debugging purposes)

CMD := "camlc camldep camllorder camllex camlyacc grep sed perl arch"

define chk_cfg
IFS=':'
for cmd in "${CMD}"; do
  found=no
  for dir in $$PATH; do
    if test -z "$$dir"; then dir=.; fi
    if test -x "$$dir/$$cmd"; then found=$$dir; break; fi
  done
  if test "$$found" = "no"
  then echo "Shell command $$cmd not found."
  else echo "Found $$found/$$cmd"
  fi
done
endef

.PHONY: conf
conf:
	@${call chk_cfg}

# ====================================================================
# Restoring consistency after deletions

ifeq (0-,${MAKELEVEL}-${MAKE_RESTARTS})
  ifneq (,${BUILD})

# Deletion of object files from standalone modules

ZI := ${filter ${IMPL_ONLY}, \
         ${basename ${notdir ${wildcard ${OBJDIR}/*.zi}}}}
ZO := ${filter ${IMPL_ONLY}, \
         ${basename ${notdir ${wildcard ${OBJDIR}/*.zo}}}}

ORPHAN_ZO := ${filter-out ${ZI},${ZO}}
ORPHAN_ZI := ${filter-out ${ZO},${ZI}}

ifeq (yes,${DEBUG})
${if ${ORPHAN_ZI},${info Deleting ${ORPHAN_ZI:%=%.zi}... done.}}
${if ${ORPHAN_ZO},${info Deleting ${ORPHAN_ZO:%=%.zo}... done.}}
endif

${foreach file,${ORPHAN_ZI},${shell rm -f ${OBJDIR}/${file}.zi}}
${foreach file,${ORPHAN_ZO},${shell rm -f ${OBJDIR}/${file}.zo}}

# Detecting deletions of sources and tags

${shell ls *.ml* .*.tag 2>/dev/null | sort -u >| .src.new}

export DELETED := \
  ${shell if test -e .src; then comm -2 -3 .src .src.new; fi}

ifeq (yes,${DEBUG})
${if ${DELETED},${info Deleted files: ${DELETED}.}}
endif

${shell mv -f .src.new .src}

from_mli = .${1}.mli.err .${1}.mli.wrn \
           .${1}.mli.ign .${1}.mli.dep ${OBJDIR}/${1}.zi

all_mli = ${1}.mli ${call from_mli,${1}}

from_ml = .${1}.ml.err .${1}.ml.wrn .${1}.ml.ign \
          .${1}.ml.dep .${1}.ml.zod ${OBJDIR}/${1}.zo

all_ml = ${1}.ml ${call from_ml,${1}}

from_mll = .${1}.mll.err ${call all_ml,${1}}

from_mly = .${1}.mly.err ${call all_ml,${1}} ${call all_mli,${1}} \
           ${1}.output ${1}.automaton ${1}.conflicts

    ifneq (,${DELETED})
# Restoring consistency after source deletions

DEL_MLL  := ${basename ${filter %.mll,${DELETED}}}
DEL_MLY  := ${basename ${filter %.mly,${DELETED}}}
DEL_MLI  := ${filter-out ${DEL_MLY}, \
               ${basename ${filter %.mli,${DELETED}}}}
DEL_ML   := ${filter-out ${DEL_MLY} ${DEL_MLL}, \
               ${basename ${filter %.ml,${DELETED}}}}
DEL_YMLI := ${filter ${YMOD},${DEL_MLI}}
DEL_YML  := ${filter-out ${DEL_YMLI},${filter ${YMOD},${DEL_ML}}}
DEL_MLI  := ${filter-out ${DEL_YMLI},${DEL_MLI}}
DEL_ML   := ${filter-out ${DEL_YML},${DEL_ML}}

export CDEL := ${strip ${DEL_MLL} ${DEL_MLY} ${DEL_ML} \
                  ${filter-out ${ML:%.ml=%},${DEL_MLI}}}

${foreach file,${DEL_MLI}, ${shell rm -f ${call from_mli,${file}}}}
${foreach file,${DEL_ML},  ${shell rm -f ${call from_ml,${file}}}}

${foreach file,${DEL_MLL}, \
   ${shell rm -f ${call from_mll,${1}}; \
           sed -i.old "/^${1}\.ml$$/d" .src}}

${foreach file,${DEL_MLY}, \
   ${shell rm -f ${call from_mly,${1}}; \
           sed -i.old -e "/^${1}\.mli$$/d" -e "/^${1}\.ml$$/d" .src}}

${foreach file,${DEL_YMLI}, \
    ${shell rm -f ${call from_mli,${file}} ${call all_ml,${file}}; \
            sed -i.old "/^${file}\.ml$$/d" .src}}

${foreach file,${DEL_YML}, \
    ${shell rm -f ${call all_mli,${file}} ${call from_ml,${file}}; \
            sed -i.old "/^${file}\.mli$$/d" .src}}

# Restoring consistency after tag deletions

DEL_TAGS     := ${patsubst .%.tag,%,${filter .%.tag,${DELETED}}}
DEL_MLI_TAGS := ${basename ${filter ${MLI},${DEL_TAGS}}}
DEL_ML_TAGS  := ${basename ${filter ${ML},${DEL_TAGS}}}
DEL_MLL_TAGS := ${basename ${filter ${MLL},${DEL_TAGS}}}
DEL_MLY_TAGS := ${basename ${filter ${MLY},${DEL_TAGS}}}

${foreach file,${DEL_MLI_TAGS}, \
   ${shell rm -f ${call from_mli,${file}}}}

${foreach file,${DEL_ML_TAGS}, \
   ${shell rm -f ${call from_ml,${file}}}}

${foreach file,${DEL_MLL_TAGS}, \
   ${shell rm -f .${file}.mll.err ${call all_ml,${file}}}}

${foreach file,${DEL_MLY_TAGS}, \
   ${shell rm -f .${file}.mly.err ${call all_ml,${file}} \
                 ${call all_mli,${file}}}}
    endif
  endif
endif

CDEL ?=

# ====================================================================
# Compilation and linking dependencies

# We add the virtual interfaces of the standalone modules, i.e.,
# modules without interfaces. WARNING: Order is relevant.

MLI_DEP  := ${INTF:%=.%.mli.dep} ${IMPL_ONLY:%=.%.mli.dep}
DEP      := ${IMPL:%=.%.ml.dep} ${MLI_DEP}
ZOD      := ${IMPL:%=.%.ml.zod} ${MLI_DEP}
DEP_BASE := ${DEP:%.dep=%}

ifneq (,${BUILD})
  ifeq (yes,${LOG_OBJ})
    ${if ${DEBUG},${info Including .zod dependencies.}}
    sinclude ${ZOD}
  else
    ${if ${DEBUG},${info Including dependencies.}}
    sinclude ${DEP}
  endif
endif

.PHONY: dep zod
dep: ${DEP}
zod: ${ZOD}

# Core and standard library

STDLIB := arg baltree bool builtin char eq exc fchar filename float \
  format fstring fvect gc genlex int hashtbl io lexing list map \
  pair parsing printexc printf queue random ref set sort stack \
  stream string sys vect

VIS_STDLIB := ${filter-out ${ALL},${STDLIB}}
SED_STDLIB := ${foreach lib,${VIS_STDLIB},s/${lib}//g;}
SED_IMPL   := ${foreach impl,${IMPL},s/${impl}\.zi/${impl}.zo/g;}

define ignore
touch .${1}${2}.ign
case ${2} in \.mli) rm -f ${OBJDIR}/${1}.zi;;
              \.ml) rm -f ${OBJDIR}/${1}.zo;;
esac
endef

%.tag: ;

# Making compilation dependencies

define mk_dep
${if ${VERB},printf "Extracting dependencies of $<..."}
camldep $< > $@
${if ${VERB},echo " done.";}
if test -s $<; then rm -f .$<.ign; fi
rm -f .$<.err .$<.wrn
sed -i.old -e "${SED_STDLIB}" \
    -e "s/.*:\(.*\)/\1/g" -e "s/\>/.zi/g" -e "s/^/$<: /g" \
    -e "s/\.mli/.zi/g; s/^\(.*\)\.ml: \(.*\)/\1.zo: \2/g" \
    -e "s/ \+/ /g" $@
endef

define mv_metadata
${if ${VERB},printf "Reassigning metadata of $*.ml to $*.mli..."}
rm -f .$*.mli.err .$*.mli.ign .$*.mli.wrn
if test -e .$*.ml.ign; then mv -f .$*.ml.ign .$*.mli.ign; fi
if test -e .$*.ml.err; then mv -f .$*.ml.err .$*.mli.err; fi
if test -e .$*.ml.wrn; then mv -f .$*.ml.wrn .$*.mli.wrn; fi
${if ${VERB},echo " done."}
endef

define forge_dep
if test -e $<
then if test "yes" = "${VERB}"
     then printf "Making dependencies of $*.mli..."
     fi
     sed -n 's/^$*.zo: $*.zi \(.*\)$$/$*.zi: \1/p' $< > $@
     if test "yes" = "${VERB}"; then echo " done."; fi
fi
${call mv_metadata}
endef

ifeq (0-,${MAKELEVEL}-${MAKE_RESTARTS})
GDEP := ${INTF_ONLY:%=.%.mli.dep} ${IMPL_ONLY:%=.%.ml.dep} \
        ${MOD:%=.%.mli.dep} ${MOD:%=.%.ml.dep}
IMPL_ONLY_TAGGED := ${filter ${TAGS:.%.ml.tag=%},${IMPL_ONLY}}
IMPL_ONLY_UNTAGGED := ${filter-out ${IMPL_ONLY_TAGGED},${IMPL_ONLY}}

# Untagged sources

${filter-out ${TAGS:%.tag=%.dep},${GDEP}}: .%.dep: %
	@${call mk_dep}

${IMPL_ONLY_UNTAGGED:%=.%.mli.dep}: .%.mli.dep: .%.ml.dep
	@${call forge_dep}

# Tagged sources

${filter ${TAGS:%.tag=%.dep},${GDEP}}: .%.dep: % .%.tag
	@${call mk_dep}

${IMPL_ONLY_TAGGED:%=.%.mli.dep}: .%.mli.dep: .%.ml.dep .%.ml.tag
	@${call forge_dep}

else
%.dep : ;
endif

# Derived dependencies

${MOD:%=.%.ml.zod} ${IMPL_ONLY:%=.%.ml.zod}: .%.ml.zod: .%.ml.dep
	@sed -e "s/^$*.zo: $*.zi \(.*\)/$*.zo: \1/g" \
       -e "s/\.zi/.zo/g" -e "s/ \+/ /g" $< > $@

# ====================================================================
# Generating lexers and parsers

%.mll %.mly: ;

define mk_lex
if test .$<.err -nt $<
then if test -e .$<.tag
     then if test .$<.err -nt .$<.tag; then up=no; fi
     else up=no
     fi
fi
if test "$$up" = "no"
then cat .$<.err
else rm -f ${call from_mll,$*}
     lines="$$(wc -l $< | sed 's/ *\([0-9]\+\) .*/\1/g')"
     printf "Making $@ from $< ($$lines lines)..."
     info=$$(camllex $< 2> .$<.err)
     if test -s .$<.err
     then echo " FAILED:"; cat .$<.err; touch $@ .$@.ign
     else echo " done:"; rm -f .$<.err
          echo $@ >> .src; sort -u -o .src .src
          if test -n "$$info"; then echo "$$info"; fi
     fi
fi
endef

${filter-out ${MLL_TAGGED:%.mll=%.ml},${LML}}: %.ml: %.mll
	@${call mk_lex}

${MLL_TAGGED:%.mll=%.ml}: %.ml: %.mll .%.mll.tag
	@${call mk_lex}

YFLAGS ?= -v

define mk_par
if test .$<.err -nt $<
then if test -e .$<.tag
     then if test .$<.err -nt .$<.tag; then up=no; fi
     else up=no
     fi
fi
if test "$$up" = "no"
then cat .$*.mly.err
     touch $*.mli .$*.mli.ign $*.ml .$*.ml.ign
else rm -f ${call from_mly,$*}
     lines="$$(wc -l $< | sed 's/ *\([0-9]\+\) .*/\1/g')"
     printf "Making $*.ml(i) from $*.mly ($$lines lines)..."
     flags="$$(cat .$*.mly.tag 2>/dev/null)"
     camlyacc ${YFLAGS} $$flags $*.mly >| .$*.mly.err 2>&1
     sed -i.old "s/^camlyacc: //g" .$*.mly.err
     if grep -qi "error[\: ]" .$*.mly.err > /dev/null 2>&1
     then echo " FAILED:"; cat .$*.mly.err
          touch $*.mli .$*.mli.ign $*.ml .$*.ml.ign
     else printf " done"
          echo $*.mli >> .src; echo $*.ml >> .src
          sort -u -o .src .src
          conf=$$(grep conflict .$*.mly.err > /dev/null 2>&1)
          if test -z "$$conf"
          then echo ':'; tail -2 $*.output; cat .$*.mly.err
               if grep -qi "warning[\: ]" .$*.mly.err > /dev/null 2>&1
               then echo "> Check warnings in .$*.mly.err."
               else rm -f .$*.mly.err
               fi
          else echo ", but:"; tail -2 $*.output; cat .$*.mly.err
               echo "> Check .$*.mly.err and transcripts."
          fi
     fi
fi
endef

${filter-out ${MLY_TAGGED:%.mly=%.mli},${YMLI}}: %.mli: %.mly
	@${call mk_par}

${MLY_TAGGED:%.mly=%.mli}: %.mli: %.mly .%.mly.tag
	@${call mk_par}

${YML}: %.ml: %.mli ;

# ====================================================================
# Compilation

CFLAGS ?=

define compile
rm -f .${1}.wrn
printf "Compiling ${1}"
flags="$$(sed -n 's/^camlc: \(.*\)/\1/p' .${1}.tag 2>/dev/null)"
printf "..."
camlc ${CFLAGS} $$flags -I ${OBJDIR} -c ${1} > .${1}.err 2>&1
lines="$$(wc -l ${1} | sed 's/ *\([0-9]\+\) .*/\1/g')"
if test -s .${1}.err
then if grep -q "Warning:" .${1}.err > /dev/null 2>&1
     then echo " done ($$lines lines)."
          mv -f .${1}.err .${1}.wrn
          echo "> Check warnings in .${1}.wrn."
          rm -f .${1}.ign
     else echo " FAILED:"; cat .${1}.err
          ${call ignore,${basename ${1}},${suffix ${1}}}
     fi
else echo " done ($$lines lines)."
     rm -f .${1}.err .${1}.ign
fi
endef

define chk_dep
dep="${notdir ${filter-out %.ml %.mli,${^:%.zi=%}}}"
for mod in $$dep; do
  if test -e .$$mod.mli.ign
  then skip="$$mod"; break
  elif test ${OBJDIR}/$$mod.zi -nt .${1}.err \
         -o ${OBJDIR}/$$mod.zi -nt .${1}.wrn
    then updates="$$mod $$updates"
  fi
done
endef

# Compiling modules having interfaces

define comp_unit
${if ${DEBUG},echo "Entering comp_unit (${1})."}
if test -s ${1}
then ${call chk_dep,${1}}
     if test -n "$$skip"
        then echo "Ignoring ${1}."
             ${call ignore,${basename ${1}},${suffix ${1}}}
     else if test -z "$$updates"
          then if test .${1}.err -nt ${1}
               then
                 if test -e .${1}.tag
                 then if test .${1}.err -nt .${1}.tag; then up=no; fi
                 else up=no
                 fi
               fi
          fi
          if test "$$up" = "no"
          then cat .${1}.err
          else ${call compile,${1}}
               if test -e $@; then mv -f $@ ${OBJDIR}; fi
          fi
     fi
fi
endef

# Compiling modules without interfaces

define comp_stand
${if ${DEBUG},echo "Entering comp_stand ($@: $*.ml)."}
if test -s $*.ml
then ${call chk_dep,$*.mli}
     if test -n "$$skip"
     then echo "Ignoring $*.ml."; ${call ignore,$*,.ml}
          mv .$*.ml.ign .$*.mli.ign
     else
       if test -z "$$updates"
       then if test .$*.mli.err -nt $*.ml
            then if test -e .$*.ml.tag
                 then
                   if test .$*.mli.err -nt .$*.ml.tag; then up=no; fi
                 else up=no
                 fi
            fi
       fi
       if test "$$up" = "no"
       then cat .$*.mli.err
       else ${call compile,$*.ml}
            if test -e $*.zi
            then mv -f $*.zi ${OBJDIR}
                 mv -f $*.zo ${OBJDIR}
            fi
            ${call mv_metadata}
       fi
     fi
fi
if test -e .$*.mli.ign -a "${MARK_STAND}" = "yes"
then echo $* >> .std; fi
endef

ifeq (no,${LOG_OBJ})
# Interfaces

${INTF_ONLY:%=%.zi} ${MOD:%=%.zi}: %.zi: .%.mli.dep
	@${call comp_unit,$*.mli}

${IMPL_ONLY:%=%.zi}: %.zi: .%.ml.dep
	@${call comp_stand}

%.zi: ;

# Implementations (bytecode)

${MOD:%=%.zo}: %.zo: .%.ml.dep
	@${call comp_unit,$*.ml}

${IMPL_ONLY:%=%.zo}: %.zo: .%.ml.dep
	@if test ! -e ${OBJDIR}/$@ -a ! -e .$*.mli.ign; \
   then ${call comp_stand}; fi

%.zo: ;

else # infer a linking order:
${INTF_ONLY:%=%.zi}: %.zi: ;
%.zi: %.zo ;

%.zo: %.ml
	@echo $* >> .lnk

%.zo: ;
endif

# ====================================================================
# Linking dependencies

define update_links
cp /dev/null .lnk
if test -z "${DEBUG}"
then printf "Determining object files... "
else printf "Determining object files...\n"
fi
${MAKE} ${IMPL:%=-W %.ml} ${BIN}.zo LOG_OBJ:=yes 2>| .circ
echo "done."
if test -s .circ
then sed -i.old -e "s/.*: //g" -e "s/\.zo <-/.zi <-/g" .circ
else rm -f .circ
fi
endef

.lnk: ${ZOD} ${if ${CDEL},FORCE}
	@for prereq in $?; do \
     if test -e $$prereq; then up=yes; break; fi; \
   done; \
   if test "$$up" = "yes"; then ${call update_links}; fi

define rm_stubs
${if ${VERB},printf "Removing stubs (if any)..."}
for parser in ${YMOD}; do
  if test -e .$$parser.mly.err
  then rm -f ${call del_mli,$$parser} ${call del_ml,$$parser}; fi
done
for lexer in ${LMOD}; do
  if test -e .$$lexer.mll.err; then rm -f ${call del_ml,$$lexer}; fi
done
${if ${VERB},echo " done."}
endef

define prelink
${if ${DEBUG},echo "Entering prelink to make $@."}
${MAKE} .lnk
if test -s .std; then
  cat .std \
| while read mod; do sed -i.old "/^$$mod$$/d" .lnk; done
fi
if grep ${BIN} .lnk > /dev/null 2>&1
then ${MAKE} $@ OBJ:="$$(echo $$(cat .lnk))"
else echo "Cannot link objects."
fi
endef

define link
rm -f $@
${if ${DEBUG},echo "Entering link: the objects are \`${OBJ}'."}
err=.${notdir $@}.err
for mod in ${OBJ}; do
  if test -e .$$mod.mli.ign -o -e .$$mod.ml.ign
    then skip=$$mod; break
  elif test ${OBJDIR}/$$mod.zo -nt .${BIN}.err
    then updates="$$mod $$updates"
  fi
done
if test -n "$$skip"
then ${if ${DEBUG},echo "A broken module is \`$$skip'."}
     echo "Cannot link objects."
elif test -e $$err -a -z "$$updates"
  then cat $$err
  else flags="$$(echo $$(cat .${notdir $@}.tag 2>/dev/null))"
       if test "${origin OBJ}" = "command line"
       then printf "Sorting object files..."
            camllorder -s ${OBJ:%=${OBJDIR}/%.zo} >| .obj 2>/dev/null
            sed -i.old -e "s/\.zo//g" -e "${SED_STDLIB}" \
                -e "s/\>/.zo/g" -e "s/^ \+//g" -e "s/ \+/ /g" .obj
            objects="$$(wc -w .obj | sed 's/ *\([0-9]\+\) .*/\1/g')"
            echo " done ($$objects objects)."
            echo "Warning: in case of tricky initialisations, set OBJ."
            if test -s .circ
            then echo "Some modules depend on each other's interfaces:"
                 cat .circ
                 echo "This is valid but may be a design issue."
            fi
            printf "Linking objects as $@..."
            camlc $$flags -I ${OBJDIR} \
                  -o $@ $$(echo $$(cat .obj)) >| $$err 2>&1
       else printf "Linking objects as $@..."
            camlc $$flags -I ${OBJDIR} \
                  -o $@ ${OBJ:%=%.zo} >| $$err 2>&1
       fi
       if test -s $$err
       then sed -i.old -e '/"_none_"/d' -e 's/Error: //g' $$err
            echo " FAILED:"; cat $$err
            if test "${origin OBJ}" = "command line"
            then echo "> Check object files in .obj."
            else echo "> Check OBJ in Makefile.cfg."
            fi
       else echo " done."; rm -f $$err
       fi
       warnings=$$(ls .*.wrn 2>/dev/null)
       if test -n "$$warnings"
       then printf "Check warnings in\n"; ls $$warnings
       fi
fi
if test -z "${DEBUG}"; then rm -f .*.old; fi
${call rm_stubs}
endef

.PHONY: FORCE
FORCE: ;

# Linking bytecode 

BYTE_TAG := ${wildcard .${BIN}.tag}

ifndef OBJ
${OBJDIR}/${BIN} ${BIN}: FORCE
	@rm -f .std
	@${MAKE} ${BIN}.zo MARK_STAND:=yes
	@${call prelink}
else
${OBJDIR}/${BIN} ${BIN}: ${OBJ:%=%.zo} ${BYTE_TAG} ${if ${CDEL},FORCE}
	@${call link}
endif

# ====================================================================
# Miscellanea

define print_warn
warnings=$$(ls .*.wrn 2>/dev/null)
if test "$$(ls .*.wrn 2>/dev/null | wc -l)" = "1"
then printf "> Check warnings in $$warnings.\n"
else printf "> Check warnings in\n"
     ls $$warnings
fi
endef

.PHONY: warn
warn:
	@${call print_warn}

.PHONY: lines
lines:
	@wc -l ${MLY} ${MLL} \
      ${filter-out ${YMLI},${MLI}} ${filter-out ${LML} ${YML},${ML}}

.PHONY: size
size:
	@sed -e "/^#/d" -e "/^$$/d" Makefile | wc -l

# Cleaning the slate (Add your own [clean::] rules in [Makefile.cfg].)

.PHONY: clean
clean::
	@rm -fr .obj .std .src .lnk ${OBJDIR} ${LML} ${YMLI} ${YML} \
          .circ .*.dep .*.zod .*.ign .*.old .*.wrn .*.err
