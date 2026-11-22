#!/bin/bash

# This script replaces the subject and run numbers in template fsf files

fsfdir=${TREW_REPO_ROOT}/fsl/level2/level2_fsf_files/ACCmod
FSF_VARS='${TREW_REPO_ROOT} ${TREW_DATA_ROOT} ${TREW_PROCESSED_DIR} ${TREW_GROUP_DIR} ${FSLDIR}'
: "${FSLDIR:?run: module load fsl}" "${TREW_REPO_ROOT:?run: source setup_env.sh}" "${TREW_DATA_ROOT:?run: source setup_env.sh}" "${TREW_PROCESSED_DIR:?run: source setup_env.sh}" "${TREW_GROUP_DIR:?run: source setup_env.sh}"
mkdir -p "$fsfdir"
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
preprocdir=${TREW_DATA_ROOT}/preprocessed/

for dir in `ls -d ${TREW_DATA_ROOT}/preprocessed/sub-*/`; do
	rawname=`basename $dir`
	subject=`echo ${rawname} | grep -Eo '[0-9]{3}'`

	  RUNS=""
	  for r in 1 2 3; do grep -qx "$subject" "$TREW_REPO_ROOT/fsl/level1/subjects_run$r.txt" && RUNS="$RUNS,$r"; done
	  RUNS=${RUNS#,}
	  case "$RUNS" in *,*) ;; *) echo "skip sub-$subject: in fewer than two run lists" >&2; continue ;; esac
	  sed 's/SUBNUM/'${subject}'/g' design_template_level2_ACCmod.fsf | envsubst "$FSF_VARS" | python3 "$TREW_REPO_ROOT/fsl/level2/trim_level2_runs.py" "$RUNS" > $fsfdir'/sub-'${subject}'_ses-01_fsf-lv2_ACCmod.fsf'

done

