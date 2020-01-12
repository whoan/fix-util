#!/usr/bin/env bash

# This script is intended to be sourced in an initialization file (eg: .bash_profile or .bashrc)

get_tag_name_by_tag_number() {
  local tag_number=${1:?You should provide a tag number}
  local spec_file=${2:?You should provide the spec file with the same format as quickfix}
  xmllint --xpath "string(//fields//field[@number=$tag_number]//@name)" "$spec_file"
}

filter_common_tags() {
  local tag_number=${1:?You should provide a tag number}
  # BeginString BodyLength MsgSeqNum SenderCompID SendingTime TargetCompID CheckSum
  local common_fix_msgs=( 8 9 34 49 52 56 10 )
  [[ " ${common_fix_msgs[*]} " =~ \ $tag_number\  ]]
}

# This function does the following:
# - Add tag name to the tag number in each field received in a message
# - Remove common tags from the messages to ease debugging
# - Remove control messages from the output: LOGON(A), LOGOUT(5), HEARTBEAT(0)
# - Prettify the output replacing \x01 by " | " if needed

# Usage:
#   add_tag_names $dictionary < file
#   or
#   some_process | add_tag_names $dictionary

# Example:
# $ delim=$'\x01'
# $ addtags <<<"8=FIX.4.2${delim}9=270${delim}35=d${delim}34=2${delim}49=some${delim}52=20180723-23:29:17.644943${delim}56=some${delim}15=USD${delim}48=12345${delim}55=XBTF8/USDF8${delim}167=FUT${delim}200=201802${delim}231=0.0001${delim}320=1532388557571741618_1${delim}322=0${delim}393=1${delim}454=1${delim}455=XBT/USD${delim}456=99${delim}541=20180223${delim}864=1${delim}865=6${delim}866=20180223${delim}969=0.000100${delim}1146=0.000100${delim}18211=N${delim}10=199${delim}"

# Output:
# > 35=d->MsgType | 15=USD->Currency | 48=12345->SecurityID | 55=XBTF8/USDF8->Symbol | 167=FUT->SecurityType | 200=201802->MaturityMonthYear | 231=0.0001->ContractMultiplier | 320=1532388557571741618_1->SecurityReqID | 322=0->SecurityResponseID | 393=1->TotalNumSecurities | 454=1->NoSecurityAltID | 455=XBT/USD->SecurityAltID | 456=99->SecurityAltIDSource | 541=20180223->MaturityDate | 864=1->NoEvents | 865=6->EventType | 866=20180223->EventDate | 969=0.000100->MinPriceIncrement | 1146=0.000100->MinPriceIncrementAmount | 18211=N->DeliveryTerm |

add_tag_names() {

  if ! which xmllint > /dev/null 2>&1; then
    echo "xmllint needs to be installed" >&2
    return 1
  fi

  local spec_file=${1:?You should provide the path to a FIX spec file. eg: ~/FIX42TT.xml}
  if ! [ -f "$spec_file" ]; then
    echo "Spec file not found -> $spec_file" >&2
    return 1
  fi

  local line
  while read -r line; do

    local delim
    if [[ "$line" =~ $'\x01' ]]; then
      delim=$'\x01'
    elif [[ "$line" =~ | ]]; then
      delim="|"
    else
      # avoid processing no-message lines
      echo "$line"
      continue
    fi

    # ignore control messages: LOGON(A), LOGOUT(5), HEARTBEAT(0)
    if [[ "$line" =~ "${delim}"\ *35=(A|5|0)\ *"${delim}" ]]; then
      continue
    fi

    # add tag name to the tag number
    local field_pair
    while read -r -d"$delim" field_pair; do
      if [[ $field_pair =~ ([0-9]+)=(.+) ]]; then
        local tag_number=${BASH_REMATCH[1]}
        local tag_value=${BASH_REMATCH[2]}

        filter_common_tags $tag_number && continue

        echo -n "$tag_number=$tag_value->$(get_tag_name_by_tag_number $tag_number $spec_file) | "
      fi
    done <<<"$line"

    echo; echo

  done
}

# Usage:
# $ command_which_generates_fix_output | prettyfix
prettifix() {
  sed --unbuffered "s/"$'\x01'"/ | /g"
}
