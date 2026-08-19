#!/bin/sh
# oh-my-opus model helpers, sourced (not executed) by the hooks. Keeps model
# resolution, id normalization, and the per-turn subagent-cap in one place.
#
# The model is read from the session transcript, not from a SessionStart
# payload. SessionStart carries a `model` field only sometimes — a headless
# `claude -p` run has none, and an interactive session started without an
# explicit --model was observed to have none either — whereas every hook
# payload carries `transcript_path`, and every assistant entry in that
# transcript records the model that produced it. Reading it there works
# however the session was launched and follows a mid-session /model switch.

# Echo the normalization candidates for a model id, one per line, in try-order:
# the id as-is, then with a trailing bracketed suffix stripped
# (claude-opus-5[1m] -> claude-opus-5), then with a trailing -YYYYMMDD date
# suffix stripped, then with both stripped (bracket first, then date).
omo_model_candidates() {
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
omo_normalize_model() {
  _bnm_nobracket=$(printf '%s' "$1" | sed 's/\[[^][]*\]$//')
  printf '%s' "$_bnm_nobracket" | sed 's/-[0-9]\{8\}$//'
}

# Return 0 iff any normalization candidate of $1 is exactly one of the model
# ids given in the remaining arguments. Bare aliases (opus, opusplan, fable,
# default) deliberately do not match.
omo_model_is() {
  _bmi_model=$1
  shift
  # Split the candidate list on newlines only and disable pathname expansion, so
  # a model id like `*` is never glob-expanded against the caller's CWD. This is
  # a sourced library, so restore IFS and the -f state to whatever they were.
  _bmi_ifs=$IFS
  case $- in *f*) _bmi_hadf=1 ;; *) _bmi_hadf=0 ;; esac
  IFS='
'
  set -f
  _bmi_ret=1
  for _bmi_c in $(omo_model_candidates "$_bmi_model"); do
    for _bmi_t in "$@"; do
      if [ "$_bmi_c" = "$_bmi_t" ]; then
        _bmi_ret=0
        break 2
      fi
    done
  done
  IFS=$_bmi_ifs
  [ "$_bmi_hadf" = "1" ] || set +f
  return "$_bmi_ret"
}

# Return 0 iff the model is Opus 5.
omo_is_opus5() {
  omo_model_is "$1" claude-opus-5
}

# Return 0 iff the model is one this plugin treats as frontier: Opus 5 or
# Fable 5. Only the overlay uses this. The overlay's argument — that a
# project's legacy method scaffolding gets in the way rather than helping — is
# about model capability, not about one model id, so it holds for Fable 5 too.
# The recap deliberately does NOT use this predicate: measured over 61 Fable
# turns the median ending message was 187 characters and only 11.5% cleared
# 1200, so a recap there would mostly be an extra call that buys nothing.
omo_is_frontier() {
  omo_model_is "$1" claude-opus-5 claude-fable-5
}

# Echo the model of the most recent MAIN-CHAIN assistant entry in a transcript,
# or nothing. Sidechain entries are a subagent's own turns — counting those
# would let a Sonnet worker mask an Opus 5 session. Scans the tail first, since
# transcripts reach megabytes, and only falls back to the whole file when the
# tail holds no assistant entry at all (a long run of tool results can do that).
_omo_last_model() {
  jq -rR 'fromjson? | select(.type == "assistant") | select(.isSidechain != true)
          | .message.model // empty' 2>/dev/null | tail -n 1
}

omo_session_model() {
  _osm_tp=$1
  [ -n "$_osm_tp" ] && [ -f "$_osm_tp" ] || return 1
  _osm_m=$(tail -n 500 "$_osm_tp" 2>/dev/null | _omo_last_model)
  [ -n "$_osm_m" ] || _osm_m=$(_omo_last_model < "$_osm_tp")
  [ -n "$_osm_m" ] || return 1
  printf '%s' "$_osm_m"
}

# Return 0 iff the transcript's current model is Opus 5. An unreadable
# transcript, or one with no assistant entry yet (the first turn of a session),
# returns non-zero — callers treat that as "unknown" and fail open.
omo_is_opus5_session() {
  _ios_m=$(omo_session_model "$1") || return 1
  omo_is_opus5 "$_ios_m"
}

# Return 0 iff the transcript's current model is a frontier model (Opus 5 or
# Fable 5). Same unknown-model behaviour as omo_is_opus5_session.
omo_is_frontier_session() {
  _ifr_m=$(omo_session_model "$1") || return 1
  omo_is_frontier "$_ifr_m"
}

# Echo the effective per-turn subagent cap for a transcript path, or nothing
# when unlimited. Resolution:
#   maxagents=0            -> unlimited (nothing)
#   maxagents=<1-99>       -> that number, regardless of model
#   maxagents=auto/missing -> cap 10 iff the session model is Opus 5, else
#                             unlimited; an unresolvable model fails OPEN
#   any other value        -> unlimited
# `auto` stays Opus-5-only on purpose, unlike the overlay's frontier gate. It is
# insurance against a fan-out that has not been observed, so it stays scoped to
# the session this plugin was built for; a Fable session that wants a ceiling
# can set an explicit maxagents=<n>, which applies regardless of model.
omo_effective_cap() {
  _bec_tp=$1
  _bec_flag="${HOME}/.claude/oh-my-opus"
  _bec_mx=$(sed -n 's/^maxagents=//p' "$_bec_flag" 2>/dev/null | tail -1)
  [ -n "$_bec_mx" ] || _bec_mx=auto
  case "$_bec_mx" in
    0)
      return 0
      ;;
    auto)
      omo_is_opus5_session "$_bec_tp" && printf '10'
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
