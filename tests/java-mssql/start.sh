#!/bin/sh
javac MsSQL.java
java MsSQL "jdbc:sqlserver://152.99.171.251:1433;user=jeongseon;password=elzb00;database=jeongseon2012" "select * from tbcb_board_file;"