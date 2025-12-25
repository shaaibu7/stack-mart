/**
 * Validation utilities for StackMart marketplace
 */

export const validateStacksAddress = (address: string): boolean => {
  if (!address) return false;
  // Stacks addresses start with SP or ST and are 39-41 characters
  const stacksAddressRegex = /^[SP][0-9A-Z]{38,40}$/;
  return stacksAddressRegex.test(address);
};

export const validatePrice = (price: string): { valid: boolean; error?: string } => {
  const numPrice = parseFloat(price);
  if (isNaN(numPrice) || numPrice <= 0) {
    return { valid: false, error: 'Price must be a positive number' };
  }
  if (numPrice > 1000000) {
    return { valid: false, error: 'Price cannot exceed 1,000,000 STX' };
  }
  return { valid: true };
};

export const validateBasisPoints = (bips: string, max: number = 10000): { valid: boolean; error?: string } => {
  const numBips = parseInt(bips);
  if (isNaN(numBips) || numBips < 0) {
    return { valid: false, error: 'Must be a non-negative integer' };
  }
  if (numBips > max) {
    return { valid: false, error: `Cannot exceed ${max} basis points (${max / 100}%)` };
  }
  return { valid: true };
};

export const formatAddress = (address: string, startChars: number = 6, endChars: number = 4): string => {
  if (!address || address.length < startChars + endChars) return address;
  return `${address.slice(0, startChars)}...${address.slice(-endChars)}`;
};

export const formatSTX = (microSTX: number | string): string => {
  const num = typeof microSTX === 'string' ? parseFloat(microSTX) : microSTX;
  if (isNaN(num)) return '0';
  return (num / 1000000).toFixed(6).replace(/\.?0+$/, '');
};

