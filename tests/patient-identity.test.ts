import { describe, it, expect, beforeEach } from "vitest"

// Mock implementation for testing Clarity contracts
const mockTxSender = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
const mockPatient = "ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG"
const mockAdmin = "ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC"

// Mock state
let state = {
  admin: mockTxSender,
  patients: new Map(),
  blockHeight: 100,
}

// Mock contract functions
const patientIdentity = {
  registerPatient: (patientId: string, name: string, dob: string, sender = mockTxSender) => {
    if (state.patients.has(patientId)) {
      return { type: "err", value: 101 } // ERR_ALREADY_REGISTERED
    }
    
    state.patients.set(patientId, {
      owner: sender,
      name,
      dob,
      active: true,
      "created-at": state.blockHeight,
    })
    
    return { type: "ok", value: true }
  },
  
  getPatient: (patientId: string) => {
    if (!state.patients.has(patientId)) {
      return null
    }
    return state.patients.get(patientId)
  },
  
  updatePatient: (patientId: string, name: string, dob: string, sender = mockTxSender) => {
    if (!state.patients.has(patientId)) {
      return { type: "err", value: 102 } // ERR_NOT_FOUND
    }
    
    const patient = state.patients.get(patientId)
    if (sender !== state.admin && sender !== patient.owner) {
      return { type: "err", value: 100 } // ERR_UNAUTHORIZED
    }
    
    state.patients.set(patientId, {
      ...patient,
      name,
      dob,
    })
    
    return { type: "ok", value: true }
  },
  
  deactivatePatient: (patientId: string, sender = mockTxSender) => {
    if (!state.patients.has(patientId)) {
      return { type: "err", value: 102 } // ERR_NOT_FOUND
    }
    
    const patient = state.patients.get(patientId)
    if (sender !== state.admin && sender !== patient.owner) {
      return { type: "err", value: 100 } // ERR_UNAUTHORIZED
    }
    
    state.patients.set(patientId, {
      ...patient,
      active: false,
    })
    
    return { type: "ok", value: true }
  },
  
  reactivatePatient: (patientId: string, sender = mockTxSender) => {
    if (!state.patients.has(patientId)) {
      return { type: "err", value: 102 } // ERR_NOT_FOUND
    }
    
    if (sender !== state.admin) {
      return { type: "err", value: 100 } // ERR_UNAUTHORIZED
    }
    
    const patient = state.patients.get(patientId)
    state.patients.set(patientId, {
      ...patient,
      active: true,
    })
    
    return { type: "ok", value: true }
  },
  
  transferAdmin: (newAdmin: string, sender = mockTxSender) => {
    if (sender !== state.admin) {
      return { type: "err", value: 100 } // ERR_UNAUTHORIZED
    }
    
    state.admin = newAdmin
    return { type: "ok", value: true }
  },
}

describe("Patient Identity Contract", () => {
  beforeEach(() => {
    // Reset state before each test
    state = {
      admin: mockTxSender,
      patients: new Map(),
      blockHeight: 100,
    }
  })
  
  it("should register a new patient", () => {
    const patientId = "patient-123"
    const result = patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    
    expect(result).toEqual({ type: "ok", value: true })
    expect(state.patients.has(patientId)).toBe(true)
    
    const patient = state.patients.get(patientId)
    expect(patient.name).toBe("John Doe")
    expect(patient.dob).toBe("1980-01-01")
    expect(patient.active).toBe(true)
  })
  
  it("should not register a patient with an existing ID", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    
    const result = patientIdentity.registerPatient(patientId, "Jane Doe", "1985-05-05")
    expect(result).toEqual({ type: "err", value: 101 }) // ERR_ALREADY_REGISTERED
  })
  
  it("should get patient information", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    
    const patient = patientIdentity.getPatient(patientId)
    expect(patient).toBeDefined()
    expect(patient.name).toBe("John Doe")
    expect(patient.dob).toBe("1980-01-01")
  })
  
  it("should update patient information by owner", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    
    const result = patientIdentity.updatePatient(patientId, "John Smith", "1980-01-01")
    expect(result).toEqual({ type: "ok", value: true })
    
    const patient = patientIdentity.getPatient(patientId)
    expect(patient.name).toBe("John Smith")
  })
  
  it("should not update patient information by unauthorized user", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01", mockTxSender)
    
    const result = patientIdentity.updatePatient(patientId, "John Smith", "1980-01-01", mockPatient)
    expect(result).toEqual({ type: "err", value: 100 }) // ERR_UNAUTHORIZED
  })
  
  it("should deactivate a patient", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    
    const result = patientIdentity.deactivatePatient(patientId)
    expect(result).toEqual({ type: "ok", value: true })
    
    const patient = patientIdentity.getPatient(patientId)
    expect(patient.active).toBe(false)
  })
  
  it("should reactivate a patient as admin", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    patientIdentity.deactivatePatient(patientId)
    
    const result = patientIdentity.reactivatePatient(patientId)
    expect(result).toEqual({ type: "ok", value: true })
    
    const patient = patientIdentity.getPatient(patientId)
    expect(patient.active).toBe(true)
  })
  
  it("should not reactivate a patient as non-admin", () => {
    const patientId = "patient-123"
    patientIdentity.registerPatient(patientId, "John Doe", "1980-01-01")
    patientIdentity.deactivatePatient(patientId)
    
    const result = patientIdentity.reactivatePatient(patientId, mockPatient)
    expect(result).toEqual({ type: "err", value: 100 }) // ERR_UNAUTHORIZED
  })
  
  it("should transfer admin rights", () => {
    const result = patientIdentity.transferAdmin(mockAdmin)
    expect(result).toEqual({ type: "ok", value: true })
    expect(state.admin).toBe(mockAdmin)
  })
})

