#!/bin/sh

UCANACCESS_HOME=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
echo UCANACCESS_HOME: $UCANACCESS_HOME

CLASSPATH="$UCANACCESS_HOME/ucanaccess-5.1.2-uber.jar"

if [ -d "$JAVA_HOME" -a -x "$JAVA_HOME/bin/java" ]; then
    JAVACMD="$JAVA_HOME/bin/java"
else
    JAVACMD=java
fi

"$JAVACMD" -jar $CLASSPATH
