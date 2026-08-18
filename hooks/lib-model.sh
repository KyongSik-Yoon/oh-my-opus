#!/bin/sh
# baton-opus5 model helpers, sourced (not executed) by agent-cap.sh. Keeps the
# model-id normalization and the per-turn subagent-cap resolution in one place.

# Echo the normalization candidates for a model id, one per line, in try-order:
# the id as-is, then with a trailing bracketed suffix stripped
# (claude-opus-5[1m] -> claude-opus-5), then with a trailing -YYYYMMDD date
# suffix stripped, then with both stripped (bracket first, then date).
baton_model_candidates() {
  _bmc_model=$1
  _bmc_nobracket=$(printf '%s' "$_bmc_model" | sed 's/\[[^][]*\]$//')
  _bmc_nodate=$(printf '%s' "$_bmc_model" | sed 's/-[0-9]\{8\}$//')
  _bmc_stripped=$(printf '%s' "$_bmc_nobracket" | sed 's/-[0-9]\{8\}$//')
  printf '%s\n%s\n%s\n%s\n' \
    "$_bmc_model" "$_bmc_nobracket" "$_bmc_nodate" "$_bmc_stripped"
}

# Echo a single fully-normalized model id: a trailing bracketed suffix stripped,
# then a trailing -YYYYMMDD date suffix stripped, in that order (and both
# together when present).
baton_normalize_model() {
  _bnm_nobracket=$(printf '%s' "$1" | sed 's/\[[^][]*\]$//')
  printf '%s' "$_bnm_nobracket" | sed 's/-[0-9]\{8\}$//'
}

# Return 0 iff any normalization candidate is exactly `claude-opus-5`. Bare
# aliases (opus, opusplan, default) deliberately do not match.
baton_is_opus5() {
  # Split the candidate list on newlines only and disable pathname expansion, so
  # a model id like `*` is never glob-expanded against the caller's CWD. This is
  # a sourced library, so restore IFS and the -f state to whatever they were.
  _bio_ifs=$IFS
  case $- in *f*) _bio_hadf=1 ;; *) _bio_hadf=0 ;; esac
  IFS='
'
  set -f
  _bio_ret=1
  for _bio_c in $(baton_model_candidates "$1"); do
    if [ "$_bio_c" = "claude-opus-5" ]; then
      _bio_ret=0
      break
    fi
  done
  IFS=$_bio_ifs
  [ "$_bio_hadf" = "1" ] || set +f
  return "$_bio_ret"
}

# Echo the effective per-turn subagent cap for a (already sanitized) session id,
# or nothing when unlimited. Resolution:
#   maxagents=0            -> unlimited (nothing)
#   maxagents=<1-99>       -> that number, regardless of model
#   maxagents=auto/missing -> cap 10 iff the session model is Opus 5, else
#                             unlimited; a missing/empty model file fails OPEN
#   any other value        -> unlimited
baton_effective_cap() {
  _bec_sid=$1
  _bec_flag="${HOME}/.claude/baton-opus5"
  _bec_state="${HOME}/.claude/baton-opus5-state"
  _bec_mx=$(sed -n 's/^maxagents=//p' "$_bec_flag" 2>/dev/null | tail -1)
  [ -n "$_bec_mx" ] || _bec_mx=auto
  case "$_bec_mx" in
    0)
      return 0
      ;;
    auto)
      _bec_mf="${_bec_state}/${_bec_sid}.model"
      [ -s "$_bec_mf" ] || return 0
      _bec_model=$(cat "$_bec_mf" 2>/dev/null)
      [ -n "$_bec_model" ] || return 0
      baton_is_opus5 "$_bec_model" && printf '10'
      return 0
      ;;
    [1-9]|[1-9][0-9])
      printf '%s' "$_bec_mx"
      return 0
      ;;
    *)
      return 0
      ;;
  esac
}
