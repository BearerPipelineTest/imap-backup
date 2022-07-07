require "email/provider/base"

class Email::Provider::Purelymail < Email::Provider::Base
  def host
    "mailserver.purelymail.com"
  end

  def sets_seen_flags_on_fetch?
    true
  end
end
