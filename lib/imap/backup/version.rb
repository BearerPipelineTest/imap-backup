module Imap; end

module Imap::Backup
  MAJOR    = 7
  MINOR    = 0
  REVISION = 0
  PRE      = nil
  VERSION  = [MAJOR, MINOR, REVISION, PRE].compact.map(&:to_s).join(".")
end
