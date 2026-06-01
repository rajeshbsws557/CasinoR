import jwt from 'jsonwebtoken';

describe('Auth Service & JWT Logic', () => {
  const mockSecret = 'test-secret';
  
  it('generates a valid JWT token', () => {
    const payload = { userId: 'user-123' };
    const token = jwt.sign(payload, mockSecret, { expiresIn: '1h' });
    
    expect(token).toBeDefined();
    expect(typeof token).toBe('string');
  });

  it('verifies a valid JWT token', () => {
    const payload = { userId: 'user-123' };
    const token = jwt.sign(payload, mockSecret, { expiresIn: '1h' });
    
    const decoded = jwt.verify(token, mockSecret) as any;
    expect(decoded.userId).toBe('user-123');
  });
});
