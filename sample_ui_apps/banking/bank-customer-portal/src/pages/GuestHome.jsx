import React from 'react';
export default function GuestHome() {
  const products = [
    { title: "Home Loans", rate: "12%" },
    { title: "Fixed Deposits", rate: "8.5%" },
    { title: "Vehicle Leasing", rate: "14%" }
  ];
  return (
    <div style={{padding: '2rem'}}>
      <h1>Welcome to City Bank</h1>
      <div style={{display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '20px'}}>
        {products.map((p, i) => (
          <div key={i} style={{border: '1px solid #ddd', padding: '20px', borderRadius: '8px'}}>
            <h3>{p.title}</h3>
            <p>Interest: {p.rate}</p>
          </div>
        ))}
      </div>
    </div>
  );
}
