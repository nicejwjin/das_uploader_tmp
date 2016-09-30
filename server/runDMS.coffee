future = require 'fibers/future'
fibers = require 'fibers'
mysql = require 'mysql'
Meteor.startup ->

  cl 'statup runDMS'

  isLicenced = ->
    encrypted = CollectionSettings.findOne(set_key: 'serial')?.value #등록일이 포함된 암호화 string
    unless encrypted? and encrypted.length > 0 then return false  #라이센스키가 없거나, value.length <= 0 이면 무조건 false

    #todo CryptoJs.AES.decrypy 가 들어가는곳에는 private key 가 들어가므로 나중에 별도 서버로 이관후 수정해야함
    decrypted = CryptoJS.AES.decrypt(encrypted, CLIENT_NAME)
    startYMD = decrypted.toString(CryptoJS.enc.Utf8)  #YYYY-MM-DD 형태의 string
    if new Date() <= new Date(startYMD).addMonths(12) then return true  #licensed 기간은 1년이므로 12개월을 더한날 09:00시를 기준으로 확인
    else return false

#로드되는 시점에 agent가 내려가 있다면 접속을 계속 시도하느라 uploader의 로드가 중단 되기 때문에
#async하게 돌려놓고 우선 서버를 구동
#근데 startup인데 왜 methods도 로드가 안된상황에서 실행이 되지?
  cl 'isLicenced : ' + isLicenced()
  setInterval ->
      fibers ->
        if isLicenced()
          runDMS()
      .run()
  , 1000 * 60 * 60


  @runDMS = ->
    cl 'runDMS'
    CollectionDasInfos.find($and: [{"STATUS.0": {$ne: "wait"}} , {STATUS: 'wait'}], DEL_DATE: {$lte: new Date()}).forEach (dasInfo) ->
      cl dasInfo._id
      # 순차적으로 모두 통과해야만 success -> success or []. error를 순차적으로 입력
      # jwjin/1609240853 최종적으로 'wait'이 아닐 경우에만 success로 변경
      # error 발생 시 이전 단계인 wait을 array에 추가함으로서 상태 변화를 명확히 함

      service = CollectionServices.findOne SERVICE_ID: dasInfo.SERVICE_ID
      unless service
        unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
        dasInfo.STATUS.push ['service not found']
        CollectionDasInfos.update _id: dasInfo._id, dasInfo
        return  #의미 없는 update rslt return을 없앰

      if service.상태 is false then return  #해당 서비스의 처리 않함 상태

#      agents = CollectionAgents.find _id: $in: service.AGENT정보
#      if agents.count() is 0
#        if dasInfo.STATUS is 'success' then dasInfo.STATUS = ['agent not found']
#        return CollectionDasInfos.update _id: dasInfo._id, dasInfo

      ## delete files
      service.AGENT정보.forEach (agentInfo) ->
        if agentInfo.파일삭제기능
          agent = CollectionAgents.findOne _id: agentInfo.agent_id
          try
            fut = new future()
            HTTP.post "#{agent.AGENT_URL}/removeFiles",
              data:
                DEL_FILE_LIST: dasInfo.DEL_FILE_LIST
                DEL_OPTION: service.파일처리옵션
                BACKUP_PATH: service.백업파일경로
            , (err, rslt) ->
              if err
                cl err.toString()
                unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
                dasInfo.STATUS.push err.toString()
#                  Error: connect ECONNREFUSED is the key for agent conn error
#                else
#                  fibers ->
#                    dasInfo.STATUS = 'success'
#                    CollectionDasInfos.update _id: dasInfo._id, dasInfo
#                  .run()
              else
#                #rslt.contents가 success가 아니면 이 역시 실패
                if rslt.content isnt 'success'
                  unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
                  dasInfo.STATUS.push rslt
                else  #최종성공시 용량통계를 위한 처리용량 누적
                  CollectionServices.update SERVICE_ID: dasInfo.SERVICE_ID,
                    $inc: '용량통계.처리용량': dasInfo.UP_FSIZE
              fut.return()
            fut.wait()

          catch err
            unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
            dasInfo.STATUS.push err.toString()
##    delete query
      switch service?.DB정보?.DBMS종류
        when 'MsSQL'
          cl "jdbc:sqlserver://#{service.DB정보.DB_IP}:#{service.DB정보.DB_PORT};user=#{service.DB정보.DB_ID};password=#{service.DB정보.DB_PW};database=#{service.DB정보.DB_DATABASE}"
          dbInfo = "jdbc:sqlserver://#{service.DB정보.DB_IP}:#{service.DB정보.DB_PORT};user=#{service.DB정보.DB_ID};password=#{service.DB정보.DB_PW};database=#{service.DB정보.DB_DATABASE}"

          dasInfo.DEL_DB_QRY.forEach (query) ->
#            query = "select * from dasuploader.dasuploader"
            query = "update TBCB_BOARD_ARTICLE set TITLE='@@AUTOMATICALLY_REMOVED_BY_DAS@@20160101@@', NAME='', EMAIL='', CONTENT='',TYPE_F='D'  where ARTICLE_SEQ=150301"
            console.log('!!!query!!!')
            console.log(query)
            cp = require 'child_process'
            fut = new future()
            cp.exec 'cd /usr/local/src/das_uploader_tmp/tests/java-mssql && java MsSQL "'+ dbInfo + '" "'+ query + '"', (err,stdout,stderr) ->
              cl err or stderr or stdout
              fut.return err or stderr or 'success'
            return fut.wait()



## jwjin/1609300454 old npm version
#          connectUrl = "mssql://#{service.DB정보.DB_ID}:#{service.DB정보.DB_PW}@#{service.DB정보.DB_IP}:#{service.DB정보.DB_PORT}/#{service.DB정보.DB_DATABASE}"
#          mssql.connect(connectUrl).then ->
#            dasInfo.DEL_DB_QRY.forEach (query) ->
#              new mssql.Request().query(query).then (recordset) ->
#                unless dasInfo.tmp or Array.isArray dasInfo.tmp then dasInfo.tmp = []
#                dasInfo.tmp.push recordset
#              .catch (err) ->
#                unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
#                dasInfo.STATUS.push err.toString()
#          .catch (err) ->
#            unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
#            dasInfo.STATUS.push err.toString()
#            mssql.close() # close timing이 더럽다. future로 sync로 바꿔얄 듯. 일단은 메모리를 믿자

        when 'MySQL'
          try
            mysqlDB = mysql.createConnection
                host: service.DB정보.DB_IP
                port: service.DB정보.DB_PORT
                user: service.DB정보.DB_ID
                password: service.DB정보.DB_PW
                database: service.DB정보.DB_DATABASE
            mysqlDB.connect()
            dasInfo.DEL_DB_QRY.forEach (query) ->
              mysqlDB.query query, (err, rows, fields) ->
                if err
                  cl 'del_db_qry for each'
                  unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
                  dasInfo.STATUS.push err.toString()
                else cl 'success!!!!!!!!!'
            mysqlDB.end()

          catch err
            cl '####### DB ERROR #######'
    #        cl dasInfo.STATUS = err.toString()
            unless Array.isArray dasInfo.STATUS then dasInfo.STATUS = [dasInfo.STATUS]
            dasInfo.STATUS.push err.toString()



##      delete url
#      if dasInfo.STATUS is 'success'
#        if dasInfo.DEL_DB_URL? and dasInfo.DEL_DB_URL.length > 0
#          fut = new future()
#          HTTP.get dasInfo.DEL_DB_URL, (err, rslt) ->
#            if err
#  #            이녀석은 async다. 나중에 처리하자.
#  #            timeout 이 너무 길어져서 다 기다릴 수가 없다
#              cl 'delete url'
#              cl dasInfo.STATUS = err.toString()
#  #            fibers ->
#  #              CollectionError.insert err
#  #            .run()
#  #          fut.return()
#  #        fut.wait()

      #      최종 dasInfo update
      # jwjin/1609240855 최종적으로 'wait' 일 경우에만 성공
      if dasInfo.STATUS is 'wait' then dasInfo.STATUS = 'success'
      CollectionDasInfos.update _id: dasInfo._id, dasInfo


