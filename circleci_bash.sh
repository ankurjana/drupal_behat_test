#!/bin/bash
# Run Load Impact test from bash

####
# Copyright 2016 Load Impact
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
#    
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
####

# Load Impact test id
# env variable from CircleCi - LI_TEST_ID
testId="$LI_TEST_ID"

# API_KEY from your Load Impact account
# env variable from CircleCi - LI_API_KEY
API_KEY="$LI_API_KEY"

uri="https://api.loadimpact.com/v2/test-configs/$testId/start"

echo "Kickoff performance test"

OUT=$(curl -qSfsw "\n%{http_code}" -u $API_KEY: -X POST https://api.loadimpact.com/v2/test-configs/$testId/start)

status=`echo  "${OUT}" | tail -n1`

# Status 201 expected, 200 is just a current running test id
if [[ $status -ne 201 ]] ; then
  perc="Could not start test $testId : $status \n $resp.Content"
  echo "${perc}"
  exit 2
else
  tid=`echo "${OUT}" | head -n1 | jq '.id'`
fi

# Until 5 minutes timout or status is running 

t=0
status_text="\"NOT_YET\""
until [ $status_text == "\"Running\"" ]; do
  sleep 10s
  OUT=$(curl -qSfsw '\n%{http_code}' -u $API_KEY: -X GET https://api.loadimpact.com/v2/tests/$tid/)
  status_text=`echo  "${OUT}" | head -n1 | jq '.status_text'`
  ((t=t+10))

  if [[ $t -gt 300 ]] ; then
    echo "Timeout - test start > 5 min"
    exit 3
  fi
done

echo "Performance test running"

# wait until completed

maxVULoadTime=0
percentage=0
until [[ $(echo "$percentage==100" | bc -l) == 1 ]]; do
  sleep 30s

  # Get percent completed
  OUT=$(curl -qSfs -u $API_KEY: -X GET https://api.loadimpact.com/v2/tests/$tid/results?ids=__li_progress_percent_total)

  percentage=`echo "${OUT}" | jq '.__li_progress_percent_total | max_by(.value)| .value'`

  echo  "Percentage completed $percentage"

  # Get VU Load Time
  OUT=$(curl -qSfs -u $API_KEY: -X GET https://api.loadimpact.com/v2/tests/$tid/results?ids=__li_user_load_time)

  maxVULoadTime=`echo "${OUT}" | jq '.__li_user_load_time | max_by(.value) | .value'`

  if [[ $(echo "$maxVULoadTime>2000" | bc -l) == 1 ]] ; then 
    perc="VU Load Time exceeded limit of 2 sec: $maxVULoadTime"
    echo "$perc"
    exit 4
  fi
done

#show results
echo "Show results"
echo "$maxVULoadTime"
echo "Max VU Load Time: $maxVULoadTime"
echo "Full results at https://app.loadimpact.com/test-runs/$tid"