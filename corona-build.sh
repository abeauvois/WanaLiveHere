#!/bin/bash

if [[ ${#SDK_PATH} > 0 ]] ; then
  CORONA_SIM_PATH=$SDK_PATH"/simulator"
else
  CORONA_SIM_PATH="/Applications/CoronaSDK/simulator"
fi

# In order for the simulator relaunch to work, "Enable access for assistive devices" must be selected in System Preferences &gt; Universal Access.
osascript corona.applescript $CORONA_SIM_PATH $1

