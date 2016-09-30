#!/bin/sh
javac MsSQL.java
java MsSQL "jdbc:sqlserver://152.99.171.251:1433;user=jeongseon2012;password=elzb00;database=jeongseon2012" "update TBCB_BOARD_ARTICLE set TITLE=\'@@AUTOMATICALLY_REMOVED_BY_DAS@@20160101@@\', NAME=\'\', EMAIL=\'\', CONTENT=\'\',TYPE_F=\'D\'  where ARTICLE_SEQ=150301"