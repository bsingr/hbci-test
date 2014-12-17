require 'java'
require File.join(File.dirname(__FILE__),'hbci4java.jar')

import 'org.kapott.hbci.manager.HBCIUtils'
import 'org.kapott.hbci.manager.HBCIUtilsInternal'
import 'org.kapott.hbci.passport.AbstractHBCIPassport'
import 'org.kapott.hbci.callback.HBCICallbackConsole'
import 'org.kapott.hbci.manager.HBCIHandler'

class MyHBCICallback < HBCICallbackConsole
  @@status_names = {}
  constants.each { |c| @@status_names[const_get(c)] = c }

  def callback(passport, reason, msg, dataType, retData)
    passphrase, pin, tan = passport.getClientData('init')
    case reason
      when NEED_PASSPHRASE_LOAD then retData.replace(0, retData.length, passphrase)
#      when NEED_PASSPHRASE_SAVE then retData.replace(0, retData.length, passphrase)
      when NEED_PT_PIN then retData.replace(0, retData.length, pin)
      when NEED_PT_TAN then retData.replace(0, retData.length, tan)
      when NEED_CONNECTION, CLOSE_CONNECTION then nil
      else super
    end
  end

  def log(msg, level, date, trace)
    puts msg
  end

  def status(passport, statusTag, o)
    puts @@status_names[statusTag]
  end
end

# Umsätze von start_date bis end_date abrufen
# * passport_type, passphrase, pin und file kommen in dieser Implementation aus der zugrunde liegenden Tabelle.
# * Wenn passport_type = "PinTan" ist, wird die pin verwendet.
# * Wenn passport_type = "RDHNew" ist, wird die Schlüsseldatei aus filename verwendet und mit der passphrase entschlüsselt.
def get_transactions(start_date, end_date)
  passport_type = 'PinTan'
  pin = ''
  filename = "connect.txt"

  HBCIUtils.setParam("client.passport.#{passport_type}.filename", filename)
  HBCIUtils.setParam("client.passport.#{passport_type}.init", '1')

  passport = AbstractHBCIPassport.getInstance(passport_type, [pin])
  handle = HBCIHandler.new(passport.getHBCIVersion, passport)
  job = handle.newJob('KUmsAll')
  my_account = passport.getAccount(self.number)

  job.setParam('my', my_account)

  ruby_startdate = start_date || (Date.today - 1)
  job.setParam('startdate', JavaUtil::Date.new(ruby_startdate.year-1900, ruby_startdate.month-1, ruby_startdate.day))

  ruby_enddate = end_date || (Date.today - 1)
  job.setParam('enddate', JavaUtil::Date.new(ruby_enddate.year-1900, ruby_enddate.month-1, ruby_enddate.day))

  job.addToQueue

  status = handle.execute

  handle.close

  if status.isOK
    result = job.getJobResult
    result.getFlatData
  else
    puts "Fehler: " + status.getErrorString
  end
end

HBCIUtils.init(nil, nil, MyHBCICallback.new)

p get_transactions(Time.new(2013), Time.now)
