#!/bin/bash

logfile=/vagrant/access.log #файл с логом
report=/vagrant/report.log #файл с отчетом
timelog=/vagrant/endtime.log #файл с датой из последней обработанной строки
templogfile=/vagrant/temp.log #временный файл, куда копируется часть лога из access.log
lockfile=/vagrant/trapfile #временный файл для trap


prep(){
	#Создать лог файл даты (если не создан) и записать в него дату из access.log
    if ! [[  -f $timelog ]];then
        head -1 $logfile | awk '{print $4}' | sed 's/\[//' > $timelog;
    fi
	#Считываем лог файл даты и передаем переменным для начала обработки access.log
	processingtime=$(cat $timelog | sed 's!/!\\/!g')
    starttime=$(cat $timelog)
	#Сохраняем все строки из access.log содержащие дату из processingtime во временный лог файл
    sed -n "/${processingtime}/,$ p" $logfile > $templogfile
	#Сохраняем из последней строки дату и записываем в лог файл даты и переменную
    tail -1 $templogfile | awk '{print $4}' | sed 's/\[//' > $timelog
    endtime=$(cat $timelog)
}

report() {
	echo " " >> $report
	echo "Дата отчета с $starttime по $endtime" >> $report
    #X IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
	echo " " >> $report
    echo "$15 IP адресов с наибольшим количеством запросов:" >> $report
    awk '{print $1}' $templogfile | sort | uniq -cd | sort -nr | head -15 | awk '{print $1 " запросов с IP адреса: " $2}' >> $report

    #Y запрашиваемых адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта
	echo " " >> $report
    echo "15 URL с наибольшим количеством запросов:" >> $report
    awk '{print $7}' $templogfile | sort | uniq -cd | sort -nr | head -15 | awk '{print $1 " запросов на: " $2}' >> $report

    #Все ошибки c момента последнего запуска
	echo " " >> $report
    echo "Все ошибки:" >> $report
    awk '($9 ~ /4../){print $9}''($9 ~ /5../){print $9}' $templogfile | sort | uniq -cd | sort -nr |  awk '{print $1 " кодов ошибки: " $2}' >> $report 

    #Список всех кодов возврата с указанием их кол-ва с момента последнего запуска
    echo " " >> $report
    echo "Список всех кодов возврата:" >> $report
    awk '{print $9}' $templogfile | sort | uniq -cd | sort -nr |  awk '{print $1 " кодов возврата: " $2}' >> $report
}
if ( set -o noclobber; echo "$$">"$lockfile" ) 2>/dev/null; then
    trap "rm -f "$lockfile";exit $?" INT TERM EXIT
    while true
        do
            prep
            report
            sleep 1
            mail -s "AccessLog отчет" "root@localhost" < $report
            rm -f $templogfile
            exit
        done
    rm -f $lockfile
    trap - INT TERM EXIT
else
    echo "Failed to acquire lockfile: $lockfile."
    echo "Held by $(cat $lockfile)"
fi

