import { describe, it, expect, beforeEach } from 'vitest';

// Mock implementation for testing Clarity contracts
const mockTxSender = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const mockPatient = 'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG';
const mockAdmin = 'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC';

// Mock state
let state = {
  admin: mockTxSender,
  consents: new Map(),
  patientConsents: new Map(),
  blockHeight: 100
};

// Mock contract functions
const consentManagement = {
  grantConsent: (
      consentId: string,
      patientId: string,
      providerId: string,
      purpose: string,
      expiresAt: number,
      sender = mockTxSender
  ) => {
    if (state.consents.has(consentId)) {
      return { type: 'err', value: 101 }; // ERR_ALREADY_EXISTS
    }
    
    if (expiresAt <= state.blockHeight) {
      return { type: 'err', value: 103 }; // ERR_EXPIRED
    }
    
    state.consents.set(consentId, {
      'patient-id': patientId,
      'provider-id': providerId,
      purpose,
      'granted-by': sender,
      'granted-at': state.blockHeight,
      'expires-at': expiresAt,
      revoked: false
    });
    
    // Add to patient-consents map
    const patientConsentKey = `${patientId}:${consentId}`;
    state.patientConsents.set(patientConsentKey, { exists: true });
    
    return { type: 'ok', value: true };
  },
  
  getConsent: (consentId: string) => {
    if (!state.consents.has(consentId)) {
      return null;
    }
    return state.consents.get(consentId);
  },
  
  isPatientConsent: (patientId: string, consentId: string) => {
    const patientConsentKey = `${patientId}:${consentId}`;
    return state.patientConsents.has(patientConsentKey);
  },
  
  verifyConsent: (consentId: string) => {
    if (!state.consents.has(consentId)) {
      return false;
    }
    
    const consent = state.consents.get(consentId);
    return !consent.revoked && consent['expires-at'] >= state.blockHeight;
  },
  
  revokeConsent: (consentId: string, sender = mockTxSender) => {
    if (!state.consents.has(consentId)) {
      return { type: 'err', value: 102 }; // ERR_NOT_FOUND
    }
    
    const consent = state.consents.get(consentId);
    if (sender !== state.admin && sender !== consent['granted-by']) {
      return { type: 'err', value: 100 }; // ERR_UNAUTHORIZED
    }
    
    state.consents.set(consentId, {
      ...consent,
      revoked: true
    });
    
    return { type: 'ok', value: true };
  },
  
  extendConsent: (consentId: string, newExpiry: number, sender = mockTxSender) => {
    if (!state.consents.has(consentId)) {
      return { type: 'err', value: 102 }; // ERR_NOT_FOUND
    }
    
    const consent = state.consents.get(consentId);
    if (sender !== consent['granted-by']) {
      return { type: 'err', value: 100 }; // ERR_UNAUTHORIZED
    }
    
    if (consent.revoked) {
      return { type: 'err', value: 104 }; // ERR_REVOKED
    }
    
    if (newExpiry <= state.blockHeight) {
      return { type: 'err', value: 103 }; // ERR_EXPIRED
    }
    
    if (newExpiry <= consent['expires-at']) {
      return { type: 'err', value: 103 }; // ERR_EXPIRED
    }
    
    state.consents.set(consentId, {
      ...consent,
      'expires-at': newExpiry
    });
    
    return { type: 'ok', value: true };
  }
};

describe('Consent Management Contract', () => {
  beforeEach(() => {
    // Reset state before each test
    state = {
      admin: mockTxSender,
      consents: new Map(),
      patientConsents: new Map(),
      blockHeight: 100
    };
  });
  
  it('should grant a new consent', () => {
    const consentId = 'consent-123';
    const patientId = 'patient-123';
    const result = consentManagement.grantConsent(
        consentId,
        patientId,
        'provider-456',
        'Share medical records for treatment',
        200
    );
    
    expect(result).toEqual({ type: 'ok', value: true });
    expect(state.consents.has(consentId)).toBe(true);
    
    const consent = state.consents.get(consentId);
    expect(consent['patient-id']).toBe(patientId);
    expect(consent['provider-id']).toBe('provider-456');
    expect(consent.revoked).toBe(false);
    
    // Check patient-consent mapping
    expect(consentManagement.isPatientConsent(patientId, consentId)).toBe(true);
  });
  
  it('should not grant a consent with expired date', () => {
    const consentId = 'consent-123';
    const result = consentManagement.grantConsent(
        consentId,
        'patient-123',
        'provider-456',
        'Share medical records for treatment',
        90 // Expired
    );
    
    expect(result).toEqual({ type: 'err', value: 103 }); // ERR_EXPIRED
  });
  
  it('should verify valid consent', () => {
    const consentId = 'consent-123';
    consentManagement.grantConsent(
        consentId,
        'patient-123',
        'provider-456',
        'Share medical records for treatment',
        200
    );
    
    const isValid = consentManagement.verifyConsent(consentId);
    expect(isValid).toBe(true);
  });
  
  it('should not verify expired consent', () => {
    const consentId = 'consent-123';
    consentManagement.grantConsent(
        consentId,
        'patient-123',
        'provider-456',
        'Share medical records for treatment',
        150
    );
    
    state.blockHeight = 160; // Current block is after expiry
    
    const isValid = consentManagement.verifyConsent(consentId);
    expect(isValid).toBe(false);
  });
  
  it('should revoke consent by granter', () => {
    const consentId = 'consent-123';
    consentManagement.grantConsent(
        consentId,
        'patient-123',
        'provider-456',
        'Share medical records for treatment',
        200
    );
    
    const result = consentManagement.revokeConsent(consentId);
    expect(result).toEqual({ type: 'ok', value: true });
    
    const consent = state.consents.get(consentId);
    expect(consent.revoked).toBe(true);
    
    const isValid = consentManagement.verifyConsent(consentId);
    expect(isValid).toBe(false);
  });
  
  it('should revoke consent by admin', () => {
    const consentId = 'consent-123'
    consentManagement.grantConsent(
        consentId,
        "patient-123",
        "provider-456",
        "Share medical records for treatment",
        200,
        mockPatient,
    )
    
    const result = consentManagement.revokeConsent(consentId, mockAdmin)
    expect(result).toEqual({ type: "err", value: 100 }) // ERR_UNAUTHORIZED
    
    // Set admin
    state.admin = mockAdmin
    
    const adminResult = consentManagement.revokeConsent(consentId, mockAdmin)
    expect(adminResult).toEqual({ type: "ok", value: true })
    
    const consent = state.consents.get(consentId)
    expect(consent.revoked).toBe(true)
  })
  
  it('should extend consent expiration', () => {
    const consentId = 'consent-123';
    consentManagement.grantConsent(
        consentId,
        'patient-123',
        'provider-456',
        'Share medical records for treatment',
        200
    );
    
    const result = consentManagement.extendConsent(consentId, 300);
    expect(result).toEqual({ type: 'ok', value: true });
    
    const consent = state.consents.get(consentId);
    expect(consent['expires-at']).toBe(300);
  });
  
  it('should not extend revoked consent', () => {
    const consentId = 'consent-123';
    consentManagement.grantConsent(
        consentId,
        'patient-123',
        'provider-456',
        'Share medical records for treatment',
        200
    );
    
    consentManagement.revokeConsent(consentId);
    
    const result = consentManagement.extendConsent(consentId, 300);
    expect(result).toEqual({ type: 'err', value: 104 }); // ERR_REVOKED
  });
});
