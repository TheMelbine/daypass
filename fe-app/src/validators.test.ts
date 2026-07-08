import { describe, it, expect } from 'vitest';
import {
  validateProxyUrl,
  validateVlessUrl,
  validateShadowsocksUrl,
  validateTrojanUrl,
  validateHysteria2Url,
  validateSocksUrl,
} from './validators';

describe('validateProxyUrl — scheme dispatch', () => {
  it('rejects empty / whitespace input', () => {
    expect(validateProxyUrl('').valid).toBe(false);
    expect(validateProxyUrl('   ').valid).toBe(false);
  });

  it('rejects an unknown scheme', () => {
    const r = validateProxyUrl('http://example.com:8080');
    expect(r.valid).toBe(false);
    expect(r.scheme).toBeUndefined();
  });

  it('trims surrounding whitespace before dispatch', () => {
    const r = validateProxyUrl(
      '  vless://11111111-2222-3333-4444-555555555555@example.com:443?type=tcp&security=reality&pbk=abc&fp=chrome#node  ',
    );
    expect(r.valid).toBe(true);
    expect(r.scheme).toBe('vless');
  });
});

describe('vless://', () => {
  it('accepts a reality vless link', () => {
    const r = validateVlessUrl(
      'vless://11111111-2222-3333-4444-555555555555@example.com:443?type=tcp&security=reality&pbk=key&sid=00&fp=chrome#My%20Node',
    );
    expect(r).toEqual({ valid: true, scheme: 'vless' });
  });

  it('accepts a plain (no query) vless link', () => {
    expect(validateVlessUrl('vless://uuid@1.2.3.4:8443').valid).toBe(true);
  });

  it('rejects missing uuid', () => {
    expect(validateVlessUrl('vless://@example.com:443').valid).toBe(false);
  });

  it('rejects a missing @ separator', () => {
    expect(validateVlessUrl('vless://example.com:443').valid).toBe(false);
  });

  it('rejects an out-of-range port', () => {
    expect(validateVlessUrl('vless://uuid@example.com:70000').valid).toBe(
      false,
    );
  });

  it('rejects a non-numeric port', () => {
    expect(validateVlessUrl('vless://uuid@example.com:abc').valid).toBe(false);
  });
});

describe('ss:// (shadowsocks)', () => {
  it('accepts SIP002 base64 userinfo', () => {
    const r = validateShadowsocksUrl(
      'ss://YWVzLTI1Ni1nY206cGFzc3dvcmQ@example.com:8388#tag',
    );
    expect(r).toEqual({ valid: true, scheme: 'ss' });
  });

  it('accepts plain method:password userinfo with a plugin query', () => {
    const r = validateShadowsocksUrl(
      'ss://aes-256-gcm:secret@1.2.3.4:8388?plugin=obfs-local;obfs=http#x',
    );
    expect(r.valid).toBe(true);
  });

  it('accepts the shadowsocks:// long form', () => {
    expect(
      validateShadowsocksUrl('shadowsocks://abc@example.com:8388').valid,
    ).toBe(true);
  });

  it('rejects missing credentials', () => {
    expect(validateShadowsocksUrl('ss://@example.com:8388').valid).toBe(false);
  });

  it('rejects a missing port', () => {
    expect(validateShadowsocksUrl('ss://abc@example.com').valid).toBe(false);
  });
});

describe('trojan://', () => {
  it('accepts a tls trojan link', () => {
    const r = validateTrojanUrl(
      'trojan://password@example.com:443?sni=example.com&type=ws#tag',
    );
    expect(r).toEqual({ valid: true, scheme: 'trojan' });
  });

  it('rejects a missing password', () => {
    expect(validateTrojanUrl('trojan://@example.com:443').valid).toBe(false);
  });

  it('rejects a missing port', () => {
    expect(validateTrojanUrl('trojan://password@example.com').valid).toBe(
      false,
    );
  });
});

describe('hysteria2:// | hy2://', () => {
  it('accepts a single-port hysteria2 link', () => {
    const r = validateHysteria2Url('hysteria2://pass@example.com:443#tag');
    expect(r).toEqual({ valid: true, scheme: 'hysteria2' });
  });

  it('accepts the hy2:// short form', () => {
    expect(validateHysteria2Url('hy2://pass@1.2.3.4:8443').valid).toBe(true);
  });

  it('accepts port-hopping ranges and lists', () => {
    expect(
      validateHysteria2Url('hysteria2://pass@example.com:20000-50000').valid,
    ).toBe(true);
    expect(
      validateHysteria2Url('hy2://pass@example.com:443,8443,9000-9100').valid,
    ).toBe(true);
  });

  it('accepts an mport port-hopping query', () => {
    expect(
      validateHysteria2Url('hysteria2://pass@example.com:443?mport=20000-30000')
        .valid,
    ).toBe(true);
  });

  it('accepts salamander obfs', () => {
    expect(
      validateHysteria2Url(
        'hysteria2://pass@example.com:443?obfs=salamander&obfs-password=x',
      ).valid,
    ).toBe(true);
  });

  it('rejects an unsupported obfs type', () => {
    expect(
      validateHysteria2Url('hysteria2://pass@example.com:443?obfs=xor').valid,
    ).toBe(false);
  });

  it('rejects an inverted port range', () => {
    expect(
      validateHysteria2Url('hysteria2://pass@example.com:50000-20000').valid,
    ).toBe(false);
  });

  it('rejects a missing password', () => {
    expect(validateHysteria2Url('hysteria2://@example.com:443').valid).toBe(
      false,
    );
  });
});

describe('socks:// | socks5://', () => {
  it('accepts socks5 with credentials', () => {
    const r = validateSocksUrl('socks5://user:pass@1.2.3.4:1080');
    expect(r).toEqual({ valid: true, scheme: 'socks' });
  });

  it('accepts anonymous socks://', () => {
    expect(validateSocksUrl('socks://example.com:1080').valid).toBe(true);
  });

  it('rejects credentials with an empty username', () => {
    expect(validateSocksUrl('socks5://:pass@1.2.3.4:1080').valid).toBe(false);
  });

  it('rejects a missing port', () => {
    expect(validateSocksUrl('socks5://1.2.3.4').valid).toBe(false);
  });

  it('is dispatched by validateProxyUrl for both forms', () => {
    expect(validateProxyUrl('socks://1.2.3.4:1080').scheme).toBe('socks');
    expect(validateProxyUrl('socks5://1.2.3.4:1080').scheme).toBe('socks');
  });
});
