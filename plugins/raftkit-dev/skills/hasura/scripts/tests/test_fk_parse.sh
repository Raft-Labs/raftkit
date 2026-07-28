#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/assert.sh"
source "$HERE/../lib/fk_parse.sh"

# parse_col splits "name:type[:not_null][:default=...][:fk=table.col]"
eval "$(parse_col "title:text:not_null")"
assert_eq "title" "$COL_NAME" "col name"
assert_eq "text"  "$COL_TYPE" "col type"
assert_eq "1"     "$COL_NOT_NULL" "not_null flag"
assert_eq ""      "$COL_DEFAULT" "no default"
assert_eq ""      "$COL_FK_TABLE" "no fk"

eval "$(parse_col "family_id:uuid:fk=families.id")"
assert_eq "family_id" "$COL_NAME" "fk col name"
assert_eq "families"  "$COL_FK_TABLE" "fk target table"
assert_eq "id"        "$COL_FK_COL" "fk target col"

eval "$(parse_col "score:int:default=0")"
assert_eq "0" "$COL_DEFAULT" "scalar default"

# rel_name for object relationships (FK columns)
assert_eq "createdByUser"   "$(rel_name_object created_by users)"        "*_by → *ByUser"
assert_eq "family"          "$(rel_name_object family_id families)"      "drop _id"
assert_eq "parentEvent"     "$(rel_name_object parent_event_id events)" "compound _id"
# Enum FK: rel name = camelCase of target enum table, ignoring owning table
assert_eq "eventStatus"     "$(rel_name_object status event_status events)" "enum FK on events"
assert_eq "calendarProvider" "$(rel_name_object provider calendar_provider calendar_accounts)" "enum FK alt"

# rel_name for array relationships (inbound FKs)
assert_eq "eventParticipants" "$(rel_name_array event_participants)" "plural camelCase"
assert_eq "users"             "$(rel_name_array users)"              "already plural"
