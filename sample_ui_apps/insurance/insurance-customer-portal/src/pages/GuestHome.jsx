import React from 'react';

export default function GuestHome() {
  const products = [
    { icon: '🏥', title: 'Health Insurance', description: 'Comprehensive medical coverage for you and your family.', highlight: 'From $120/month' },
    { icon: '❤️', title: 'Life Insurance', description: 'Secure your loved ones financial future with life cover.', highlight: 'From $50/month' },
    { icon: '🚗', title: 'Auto Insurance', description: 'Full and third-party cover for your vehicle.', highlight: 'From $80/month' },
    { icon: '🏠', title: 'Home Insurance', description: 'Protect your home and belongings against unexpected events.', highlight: 'From $60/month' },
  ];

  return (
    <div style={{ padding: '2rem' }}>
      <div style={{ textAlign: 'center', marginBottom: '3rem' }}>
        <h1 style={{ fontSize: '2.5rem', color: 'var(--color-primary)', marginBottom: '0.5rem' }}>
          Welcome to InsureMe
        </h1>
        <p style={{ color: 'var(--color-text-sub)', fontSize: '1.1rem' }}>
          Trusted coverage for every stage of life
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '20px' }}>
        {products.map((p, i) => (
          <div key={i} className="card" style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '2.5rem', marginBottom: '0.75rem' }}>{p.icon}</div>
            <h3 style={{ color: 'var(--color-primary)', margin: '0 0 0.5rem' }}>{p.title}</h3>
            <p style={{ color: 'var(--color-text-sub)', fontSize: '0.9rem', marginBottom: '1rem' }}>
              {p.description}
            </p>
            <span style={{
              background: '#e6f4f4', color: 'var(--color-primary)',
              padding: '4px 12px', borderRadius: '20px', fontSize: '0.85rem', fontWeight: 600
            }}>
              {p.highlight}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
