cl = console.log
mssql = require 'mssql'

mssql.connect('mssql://sa:mStartup!24@52.78.177.44:1433/dasuploader').then ->
  new mssql.Request().query('select * from dasuploader.dasuploader').then (recordset) ->
    cl 'recordset'
    cl recordset
    mssql.close()
  .catch (err) ->
    cl 'err'
    cl err.toString()
    mssql.close()
.catch (err) ->
  cl err.toString()
  mssql.close()



