#!/usr/bin/env ruby
# frozen_string_literal: true

require "openssl"
require "base64"
require "json"

if ARGV.length < 2
  puts "Usage: ruby generate_apple_secret.rb <path_to_p8_file> <key_id> [team_id] [client_id]"
  puts "Default team_id: N5Q948HNBR"
  puts "Default client_id: com.jiacong.spiritbound"
  exit 1
end

p8_path = ARGV[0]
key_id = ARGV[1]
team_id = ARGV[2] || "N5Q948HNBR"
client_id = ARGV[3] || "com.jiacong.spiritbound"

unless File.exist?(p8_path)
  puts "Error: File not found: #{p8_path}"
  exit 1
end

p8_content = File.read(p8_path)
key = OpenSSL::PKey::EC.new(p8_content)

def base64url(str)
  Base64.urlsafe_encode64(str, padding: false)
end

now = Time.now.to_i
exp = now + (180 * 24 * 60 * 60) # 180 days (maximum allowed by Apple is 6 months)

header = {
  alg: "ES256",
  kid: key_id,
  typ: "JWT"
}

payload = {
  iss: team_id,
  iat: now,
  exp: exp,
  aud: "https://appleid.apple.com",
  sub: client_id
}

header_b64 = base64url(header.to_json)
payload_b64 = base64url(payload.to_json)
signing_input = "#{header_b64}.#{payload_b64}"

der_sig = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
asn1 = OpenSSL::ASN1.decode(der_sig)
r = asn1.value[0].value.to_s(2).rjust(32, "\x00")[-32..-1]
s = asn1.value[1].value.to_s(2).rjust(32, "\x00")[-32..-1]
sig_b64 = base64url(r + s)

jwt = "#{signing_input}.#{sig_b64}"

puts "\n=== Generated Apple Client Secret JWT (Valid for 180 days) ==="
puts jwt
puts "==============================================================\n"
