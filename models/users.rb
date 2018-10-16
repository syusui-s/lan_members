require 'mongoid'
require 'openssl'
require 'base64'
require_relative '../lib/arp_scan'
Mongoid.load!('./config/mongoid.yml')

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :identifier, :type => String                   # ID
  field :name, :type => String                         # Name
  field :hosts, :type => Hash, :default => {}          # Hosts (MAC Addresses)
  field :last_presence, :type => Time                  # Last Presence Timestamp
  field :monthly_report, :type => Hash, :default => {} # Monthly Presense Time
  field :privacy, :type => Hash, :default => {}        # Privacy Settings
  field :authinfo, :type => Array, :default => []      # Authentication Information [{ password: { salt: "", hashed: "" }, twitter }]

  attr_readonly :authinfo

  validates :identifier,     :presence => true
  validates :identifier,     :uniqueness => true
  validates :identifier,     :uniqueness => { :message => "ユーザ名がすでに使用されています。別のものを指定してください。" }
  validates :identifier,     :format => { with: /\A[A-Za-z0-9]+\z/ , :message => "ユーザ名に使用できない文字が含まれています。A-Za-z0-9のみ使用できます。"}
  validates :identifier,     :length => { minimum: 1, maximum: 16 , :message => "ユーザ名の長さは、1〜16文字でなければなりません。"}
  validates :name,           :presence => true
  validates :name,           :length => { minimum: 1, maximum: 16 , :message => "名前は1〜16文字でなければなりません。"}
  validates :hosts,          :length => { maximum: 16 , :message => "ホストの数は16個に制限されています。"}
  validates :authinfo,       :presence => true
  validates :authinfo,       :length => { minimum: 1, maximum: 4  , :message => "ログイン方法は1〜4個に制限されています。"}
  validate :hostname_check
  validate :hostmac_check

  def hostname_check
    errors.add(:hosts, "ホスト名は1~16文字でなければなりません。") unless self.hosts.all?{|name, _| name.is_a?(String) and name.length <= 16 }
  end

  def hostmac_check
    errors.add(:hosts, "MACアドレスが不正な形式です。") unless self.hosts.all?{|_, mac| mac.is_a?(String) and mac =~ /\A#{(["[0-9a-f]{2}"]*6).join(":")}\z/ }
  end

  def self.hash_password(password, salt)
    return OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 14348, 128, "sha512")
  end

  def store_password(password, salt = nil)
    return unless password
    salt ||= OpenSSL::Random.random_bytes(128)
    hashed = self.class.hash_password(password, salt)
    encoded_salt   = Base64.encode64(salt)
    encoded_hashed = Base64.encode64(hashed)
    if found = self.authinfo.find{|e| e[:method] == :password}
      found.update(:salt => encoded_salt, :hashed => encoded_hashed)
    else
      authinfo.push({:method => :password, :salt => encoded_salt, :hashed => encoded_hashed})
    end
  end

  def self.authenticate(identifier, info) # info = { method: :password, ... method peculiar infos ... }
    user = self.where(identifier: identifier).first
    if info and method = info[:method] and user and userinfo = user.authinfo.find{|e| e["method"] == method }
      case method
      when :password
        return user if passwd = info[:password] and salt = userinfo["salt"] and hashed = userinfo["hashed"] and
                       self.hash_password(passwd, Base64.decode64(salt)) == Base64.decode64(hashed)
      end
    end
    return nil
  end

  def append_host(hostname, macaddr)
    self.hosts[hostname.to_s] = macaddr.to_s.downcase
  end

  def delete_host(macaddr)
    before_length = self.hosts.length
    self.hosts.delete_if{|_, mac| mac == macaddr.downcase }
    return self.hosts.length != before_length
  end

  ONLINE_TIME_INTERVAL = 600     # 10 minutes
  ACTIVE_TIME_INTERVAL = 2629744 # 1 month

  # ONLINE_TIME_INTERVAL前より最近にアクティブだったか
  def online?
    self.last_presence >= (Time.now - ONLINE_TIME_INTERVAL)
  end

  # 今月の累積時間
  def monthly_accumlated_time
    self.monthly_report[self.class.format_month(Time.now)]
  end

  # ARPScanの結果を参照して、ユーザの情報を更新する
  # force_update = 強制アップデートの有効化
  # users        = アップデートするユーザのEnumerableまたはMongoidのCollection
  def self.update_status(force_update: false, users: User.all)
    return unless Time.now > (ARPScan.last_scan + ONLINE_TIME_INTERVAL) or force_update

    scanned = ARPScan.scan()
    users.each do |user|
      if not user.hosts.empty? and user.hosts.any?{|name, mac| scanned.any?{|host| host.mac_addr.downcase == mac } }
        if not user.last_presence or ARPScan.last_scan() > user.last_presence
          user.last_presence = ARPScan.last_scan()
          key = self.format_month(ARPScan.last_scan())
          user.monthly_report[key] = (user.monthly_report[key] || 0) + 10
          user.save
        end
      end
    end
  end

  # ACTIVE_TIME_INTERVAL前より最近にアクティブだったユーザのコレクション
  def self.active_users
    self.where(:last_presence.gt => (Time.now - ACTIVE_TIME_INTERVAL)).desc(:last_presence)
  end

  # ONLINE_TIME_INTERVAL前にオンラインだったユーザのコレクション
  def self.online_users
    self.where(:last_presence.gt => (Time.now - ONLINE_TIME_INTERVAL))
  end

  # 今月中にアクティブだったユーザのコレクション
  def self.monthly_active_users
    self.where(:"monthly_report.#{self.format_month(Time.now)}".ne => nil).to_a
  end

  def self.format_month(time)
    return time.strftime("%Y-%m")
  end
end
