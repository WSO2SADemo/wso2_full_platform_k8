import Sidebar from './Sidebar';

export default function Layout({ children }) {
  return (
    <div className="min-h-screen">
      <Sidebar />
      <main className="ml-60 p-6">{children}</main>
    </div>
  );
}
