require 'java'
require File.join(File.dirname(__FILE__),'hbci4java.jar')

import 'org.kapott.hbci.manager.HBCIUtils'
import 'org.kapott.hbci.manager.HBCIUtilsInternal'
import 'org.kapott.hbci.passport.AbstractHBCIPassport'
import 'org.kapott.hbci.callback.AbstractHBCICallback'
import 'org.kapott.hbci.manager.HBCIHandler'

class BankingPassport
  attr_accessor :hbci_version, :pin, :user_id, :customer_id,
                :country_code, :port, :host, :filter,
                :bank_number, :account_number
end

class MyHBCICallback < AbstractHBCICallback
  @@status_names = {}
  constants.each { |c| @@status_names[const_get(c)] = c }
attr_accessor :bp

  def build_answer banking_passport
    answer = {}
    answer[NEED_PT_PIN]     = banking_passport.pin
    answer[NEED_CUSTOMERID] = banking_passport.customer_id
    answer[NEED_USERID]     = banking_passport.user_id
    answer[NEED_COUNTRY]    = banking_passport.country_code
    answer[NEED_BLZ]        = banking_passport.bank_number
    answer[NEED_FILTER]     = banking_passport.filter
    answer[NEED_HOST]       = banking_passport.host
    answer[NEED_PORT]       = banking_passport.port
    answer
  end

  def callback(passport, reason, msg, dataType, retData)
    passphrase, pin, tan = passport.getClientData('init')

    # for reason enum definitions see HBCICallback.java in hbci4java

    answer = build_answer(bp)[reason]
    if answer
      retData.replace(0, retData.length, answer)
    else
      case reason
        when NEED_PASSPHRASE_LOAD then retData.replace(0, retData.length, passphrase)
        when NEED_PASSPHRASE_SAVE then retData.replace(0, retData.length, "foo")
        when NEED_PT_PIN then retData.replace(0, retData.length, pin)
        when NEED_PT_TAN then retData.replace(0, retData.length, tan)
        when NEED_CONNECTION, CLOSE_CONNECTION then nil
        else puts "not implemented #{reason}"
      end
    end
  end

  def log(msg, level, date, trace)
    #puts msg
  end

  def status(passport, statusTag, o)
    #puts @@status_names[statusTag]
  end
end

# Umsätze von start_date bis end_date abrufen
# * passport_type, passphrase, pin und file kommen in dieser Implementation aus der zugrunde liegenden Tabelle.
# * Wenn passport_type = "PinTan" ist, wird die pin verwendet.
# * Wenn passport_type = "RDHNew" ist, wird die Schlüsseldatei aus filename verwendet und mit der passphrase entschlüsselt.
def get_transactions(banking_passport, start_date, end_date)
  passport = AbstractHBCIPassport.getInstance('PinTan', [])
  handle = HBCIHandler.new(banking_passport.hbci_version, passport)
  job = handle.newJob('KUmsAll')
  my_account = passport.getAccount(banking_passport.account_number)

  job.setParam('my', my_account)

  ruby_startdate = start_date || (Date.today - 1)
  job.setParam('startdate', java.util.Date.new(ruby_startdate.year-1900, ruby_startdate.month-1, ruby_startdate.day))

  ruby_enddate = end_date || (Date.today - 1)
  job.setParam('enddate', java.util.Date.new(ruby_enddate.year-1900, ruby_enddate.month-1, ruby_enddate.day))

  job.addToQueue

  status = handle.execute

  handle.close

  if status.isOK
    result = job.getJobResult
    result.getFlatData.to_a
  else
    puts "Fehler: " + status.getErrorString
  end
end

banking_passport = BankingPassport.new
banking_passport.hbci_version    = '300'
banking_passport.host            = 'fints.comdirect.de/fints'
banking_passport.port            = '443'
banking_passport.filter          = 'Base64'
banking_passport.country_code    = 'DE'
banking_passport.bank_number     = 'xxx'
banking_passport.customer_id     = 'xxx'
banking_passport.user_id         = 'xxx'
banking_passport.account_number  = 'xxx'
banking_passport.pin             = 'xxx'
cb = MyHBCICallback.new
cb.bp = banking_passport
HBCIUtils.init(nil, cb)

HBCIUtils.setParam("client.product.name","HBCI4Java")
HBCIUtils.setParam("client.product.version","2.5")
HBCIUtils.setParam("client.passport.default","PinTan")
HBCIUtils.setParam("client.retries.passphrase","2")
#client.passport.PinTan.filename=./passports/institute_X_user_Y.dat
# client.passport.PinTan.certfile=hbcicerts.bin
HBCIUtils.setParam("client.passport.PinTan.checkcert","1")
HBCIUtils.setParam("client.passport.PinTan.init","1")
HBCIUtils.setParam("client.passport.PinTan.filename", 'pintan.dat')

$r = get_transactions(banking_passport, Time.new(2013), Time.now)
p $r[0].to_string

require 'irb'
IRB.start

