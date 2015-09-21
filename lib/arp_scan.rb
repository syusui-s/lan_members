#! ruby -Ku

module ARPScan
  # arp-scanの出力ディレクトリ
  # 別途cronで出力してやる必要あり
  ARPSCAN_OUTPUT_PATH = '/tmp/arp_scan'

  # ネットワーク上のホストを表す
  class Host
    attr_reader :ip_addr, :mac_addr, :host_info
    def initialize(ip_addr, mac_addr, host_info)
      @ip_addr   = ip_addr
      @mac_addr  = mac_addr
      @host_info = host_info
    end
  end

  # 出力ファイルから読み込み、Nodeのリストにして返す
  def scan()
    file_update_time = File::ctime(ARPSCAN_OUTPUT_PATH).round(0)
    if file_update_time != @@last_scan
      @@last_scan = file_update_time
      output = File::read(ARPSCAN_OUTPUT_PATH)

      @@last_result = output.each_line.map{|line|
        match = line.match(/^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-f:]{17})\s+(.+)$/)
        next Host.new(match[1], match[2], match[3]) if match
      }.compact!
    end
    return @@last_result
  end

  def last_scan()
    @@last_scan ||= Time.new(0)
    return @@last_scan
  end
  module_function :scan, :last_scan
end
