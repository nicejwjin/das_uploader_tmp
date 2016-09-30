#!/bin/sh
javac MsSQL.java
java MsSQL "jdbc:sqlserver://152.99.171.251:1433;user=dasjeongseon;password=dasjeongseon123;database=jeongseon2012" "select top 1 * from tbcb_board_file;"