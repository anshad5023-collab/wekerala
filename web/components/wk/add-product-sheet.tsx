'use client';
import { useState, useRef, ChangeEvent } from 'react';
import { ref as storageRef, uploadBytes, getDownloadURL } from 'firebase/storage';
import { storage } from '@/lib/firebase';
import { WK } from '@/lib/wk-constants';

type Mode = 'manual' | 'image' | 'sheets';

interface Product {
  name: string;
  price: string;
  category: string;
  description: string;
  imageUrl: string;
}

interface Props {
  open: boolean;
  shopId: string;
  onClose: () => void;
  onSaved?: () => void;
}

const empty = (): Product => ({ name: '', price: '', category: '', description: '', imageUrl: '' });

const inputStyle: React.CSSProperties = {
  width: '100%',
  padding: '11px 12px',
  background: 'rgba(254,250,224,0.06)',
  border: `1px solid rgba(254,250,224,0.2)`,
  borderRadius: 10,
  outline: 'none',
  fontFamily: "var(--font-jetbrains), 'JetBrains Mono', monospace",
  fontSize: 12,
  color: '#fefae0',
  boxSizing: 'border-box',
  marginBottom: 8,
};

function btn(disabled: boolean): React.CSSProperties {
  return {
    width: '100%',
    padding: '13px 0',
    background: disabled ? 'rgba(254,250,224,0.15)' : '#fefae0',
    color: disabled ? '#a8a08a' : '#283618',
    border: 'none',
    borderRadius: 12,
    cursor: disabled ? 'not-allowed' : 'pointer',
    fontFamily: "var(--font-jetbrains), 'JetBrains Mono', monospace",
    fontSize: 12,
    marginTop: 4,
  };
}

export function AddProductSheet({ open, shopId, onClose, onSaved }: Props) {
  const [mode, setMode] = useState<Mode>('manual');
  const [product, setProduct] = useState<Product>(empty());
  const [sheetProducts, setSheetProducts] = useState<Product[]>([]);
  const [sheetsUrl, setSheetsUrl] = useState('');
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [previewUrl, setPreviewUrl] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  if (!open) return null;

  const reset = () => {
    setProduct(empty()); setSheetProducts([]); setSheetsUrl('');
    setError(''); setSuccess(''); setPreviewUrl('');
  };

  const handleClose = () => { reset(); onClose(); };

  const set = (k: keyof Product) => (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) =>
    setProduct((p) => ({ ...p, [k]: e.target.value }));

  const handleImagePick = async (e: ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(''); setUploading(true);
    try {
      const sRef = storageRef(storage, `product-images/${shopId}/${Date.now()}_${file.name}`);
      await uploadBytes(sRef, file);
      const url = await getDownloadURL(sRef);
      setProduct((p) => ({ ...p, imageUrl: url }));
      setPreviewUrl(url);
    } catch {
      setError('Upload failed. Check Firebase Storage rules allow authenticated uploads.');
    } finally {
      setUploading(false);
    }
  };

  const importSheets = async () => {
    setError(''); setLoading(true);
    try {
      const res = await fetch(`/api/sheets-import?url=${encodeURIComponent(sheetsUrl)}`);
      const data = await res.json();
      if (!res.ok) throw new Error(data.error ?? 'Import failed');
      setSheetProducts(data.products ?? []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Import failed');
    } finally {
      setLoading(false);
    }
  };

  const saveOne = async (p: Product) => {
    const res = await fetch('/api/products', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ shopId, product: p }),
    });
    if (!res.ok) throw new Error('Save failed');
  };

  const handleSave = async () => {
    if (!product.name || !product.price) { setError('Name and price are required'); return; }
    setError(''); setLoading(true);
    try {
      await saveOne(product);
      setSuccess('Product added!');
      setTimeout(() => { reset(); onSaved?.(); onClose(); }, 1000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed');
    } finally { setLoading(false); }
  };

  const handleBulkSave = async () => {
    if (!sheetProducts.length) return;
    setError(''); setLoading(true);
    try {
      await Promise.all(sheetProducts.map(saveOne));
      setSuccess(`${sheetProducts.length} products added!`);
      setTimeout(() => { reset(); onSaved?.(); onClose(); }, 1000);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed');
    } finally { setLoading(false); }
  };

  const modeLabel: Record<Mode, string> = { manual: '✎ type', image: '📷 image', sheets: '📊 sheets' };

  return (
    <div
      style={{ position: 'fixed', inset: 0, zIndex: 1000, background: 'rgba(0,0,0,0.65)', display: 'flex', alignItems: 'flex-end', justifyContent: 'center' }}
      onClick={handleClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        style={{ background: WK.paper, width: '100%', maxWidth: 480, borderRadius: '20px 20px 0 0', padding: 20, paddingBottom: 44, maxHeight: '90vh', overflowY: 'auto' }}
      >
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 }}>
          <span style={{ fontFamily: WK.hand, fontSize: 22, color: WK.ink }}>add product</span>
          <button onClick={handleClose} style={{ background: 'transparent', border: 'none', cursor: 'pointer', fontFamily: WK.mono, fontSize: 18, color: WK.muted }}>✕</button>
        </div>

        {/* Mode selector */}
        <div style={{ display: 'flex', gap: 6, marginBottom: 18 }}>
          {(['manual', 'image', 'sheets'] as Mode[]).map((m) => (
            <button
              key={m} onClick={() => setMode(m)}
              style={{
                flex: 1, padding: '8px 0', borderRadius: 10, cursor: 'pointer',
                border: `1px solid ${mode === m ? WK.ink : 'rgba(254,250,224,0.2)'}`,
                background: mode === m ? 'rgba(254,250,224,0.1)' : 'transparent',
                fontFamily: WK.mono, fontSize: 10,
                color: mode === m ? WK.ink : WK.muted,
              }}
            >{modeLabel[m]}</button>
          ))}
        </div>

        {/* Manual mode */}
        {mode === 'manual' && (
          <>
            <input type="text" value={product.name} onChange={set('name')} placeholder="product name *" style={inputStyle} />
            <input type="number" value={product.price} onChange={set('price')} placeholder="price (₹) *" style={inputStyle} />
            <input type="text" value={product.category} onChange={set('category')} placeholder="category (e.g. Drinks)" style={inputStyle} />
            <input type="text" value={product.description} onChange={set('description')} placeholder="description" style={inputStyle} />
            <input type="text" value={product.imageUrl} onChange={set('imageUrl')} placeholder="image URL (optional)" style={inputStyle} />
            {product.imageUrl && (
              <img src={product.imageUrl} alt="preview" style={{ width: '100%', height: 130, objectFit: 'cover', borderRadius: 10, marginBottom: 8 }} />
            )}
            <button onClick={handleSave} disabled={loading || !product.name || !product.price} style={btn(loading || !product.name || !product.price)}>
              {loading ? 'saving…' : 'save product'}
            </button>
          </>
        )}

        {/* Image mode */}
        {mode === 'image' && (
          <>
            <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, marginBottom: 12, lineHeight: 1.6 }}>
              Pick a product photo, then fill in the details.
            </p>
            <input type="file" accept="image/*" ref={fileRef} onChange={handleImagePick} style={{ display: 'none' }} />
            {previewUrl ? (
              <div style={{ position: 'relative', marginBottom: 12 }}>
                <img src={previewUrl} alt="preview" style={{ width: '100%', height: 170, objectFit: 'cover', borderRadius: 12 }} />
                <button
                  onClick={() => { setPreviewUrl(''); setProduct((p) => ({ ...p, imageUrl: '' })); fileRef.current?.click(); }}
                  style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(40,54,24,0.85)', border: `1px solid ${WK.ink}`, borderRadius: 8, padding: '4px 10px', cursor: 'pointer', fontFamily: WK.mono, fontSize: 10, color: WK.ink }}
                >change</button>
              </div>
            ) : (
              <button
                onClick={() => fileRef.current?.click()} disabled={uploading}
                style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 8, width: '100%', minHeight: 110, border: `1.5px dashed rgba(254,250,224,0.3)`, borderRadius: 14, background: 'transparent', cursor: uploading ? 'wait' : 'pointer', marginBottom: 12 }}
              >
                <span style={{ fontSize: 28 }}>📷</span>
                <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted }}>{uploading ? 'uploading…' : 'tap to pick image'}</span>
              </button>
            )}
            {previewUrl && (
              <>
                <input type="text" value={product.name} onChange={set('name')} placeholder="product name *" style={inputStyle} />
                <input type="number" value={product.price} onChange={set('price')} placeholder="price (₹) *" style={inputStyle} />
                <input type="text" value={product.category} onChange={set('category')} placeholder="category" style={inputStyle} />
                <input type="text" value={product.description} onChange={set('description')} placeholder="description" style={inputStyle} />
                <button onClick={handleSave} disabled={loading || !product.name || !product.price} style={btn(loading || !product.name || !product.price)}>
                  {loading ? 'saving…' : 'save product'}
                </button>
              </>
            )}
          </>
        )}

        {/* Sheets mode */}
        {mode === 'sheets' && (
          <>
            <p style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted, marginBottom: 10, lineHeight: 1.7 }}>
              Make your Google Sheet public and paste the link below.<br />
              Columns: <span style={{ color: WK.ink }}>name, price, category, description, imageUrl</span>
            </p>
            <input
              type="url" value={sheetsUrl} onChange={(e) => setSheetsUrl(e.target.value)}
              placeholder="https://docs.google.com/spreadsheets/d/…"
              style={{ ...inputStyle, marginBottom: 10 }}
            />
            <button onClick={importSheets} disabled={loading || !sheetsUrl} style={btn(loading || !sheetsUrl)}>
              {loading ? 'importing…' : 'import sheet'}
            </button>

            {sheetProducts.length > 0 && (
              <div style={{ marginTop: 16 }}>
                <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.sticky, marginBottom: 8 }}>
                  {sheetProducts.length} product{sheetProducts.length !== 1 ? 's' : ''} found:
                </p>
                {sheetProducts.slice(0, 4).map((p, i) => (
                  <div key={i} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 10px', borderRadius: 8, background: 'rgba(254,250,224,0.05)', marginBottom: 4 }}>
                    <span style={{ fontFamily: WK.hand, fontSize: 14, color: WK.ink }}>{p.name}</span>
                    <span style={{ fontFamily: WK.mono, fontSize: 11, color: WK.muted }}>₹{p.price}</span>
                  </div>
                ))}
                {sheetProducts.length > 4 && (
                  <p style={{ fontFamily: WK.mono, fontSize: 10, color: WK.muted, marginBottom: 8 }}>+ {sheetProducts.length - 4} more</p>
                )}
                <button onClick={handleBulkSave} disabled={loading} style={{ ...btn(loading), marginTop: 8 }}>
                  {loading ? 'saving…' : `save all ${sheetProducts.length} products`}
                </button>
              </div>
            )}
          </>
        )}

        {error && <p style={{ fontFamily: WK.mono, fontSize: 11, color: '#ef4444', marginTop: 12, textAlign: 'center' }}>{error}</p>}
        {success && <p style={{ fontFamily: WK.mono, fontSize: 11, color: '#4ade80', marginTop: 12, textAlign: 'center' }}>{success}</p>}
      </div>
    </div>
  );
}
