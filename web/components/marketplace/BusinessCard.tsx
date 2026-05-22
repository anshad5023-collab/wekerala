import { useRouter } from 'next/navigation';

interface BusinessCardProps {
  id: string;
  collection: string;
  name: string;
  category?: string;
  district?: string;
  avgRating?: number;
  ratingCount?: number;
  isVerified?: boolean;
  isFeatured?: boolean;
  photoUrl?: string;
  serviceTypes?: string[];
  phone?: string;
  about?: string;
}

export function BusinessCard({
  id,
  collection,
  name,
  category,
  district,
  avgRating,
  ratingCount,
  isVerified,
  isFeatured,
  photoUrl,
  serviceTypes = [],
  phone,
}: BusinessCardProps) {
  const router = useRouter();
  const href = `/listing/${collection}/${id}`;
  const initial = name?.charAt(0)?.toUpperCase() ?? '?';
  const visibleTags = serviceTypes.slice(0, 3);
  const extraTagCount = serviceTypes.length - visibleTags.length;

  function handleCardClick() {
    router.push(href);
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      router.push(href);
    }
  }

  return (
    <div
      onClick={handleCardClick}
      onKeyDown={handleKeyDown}
      role="button"
      tabIndex={0}
      className="flex gap-3 bg-white rounded-2xl shadow-sm border border-gray-100 p-3 cursor-pointer hover:shadow-md transition-shadow w-full text-left"
      aria-label={`View ${name}`}
    >
      {/* Thumbnail */}
      <div className="flex-shrink-0 w-16 h-16 rounded-xl overflow-hidden bg-[#283618] flex items-center justify-center">
        {photoUrl ? (
          <img
            src={photoUrl}
            alt={name}
            className="w-full h-full object-cover"
          />
        ) : (
          <span className="text-[#fefae0] font-semibold text-xl">{initial}</span>
        )}
      </div>

      {/* Right column */}
      <div className="flex-1 min-w-0 flex flex-col gap-1">
        {/* Row 1: Name + badges */}
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="font-semibold text-gray-900 text-sm leading-tight truncate max-w-[120px]">
            {name}
          </span>
          {isVerified && (
            <span className="inline-flex items-center text-[10px] font-medium text-green-700 bg-green-50 border border-green-200 rounded-full px-1.5 py-0.5 flex-shrink-0">
              ✓
            </span>
          )}
          {isFeatured && (
            <span className="inline-flex items-center text-[10px] font-medium text-orange-700 bg-orange-50 border border-orange-200 rounded-full px-1.5 py-0.5 flex-shrink-0">
              ⭐
            </span>
          )}
        </div>

        {/* Row 2: Category + district */}
        {(category || district) && (
          <div className="text-[11px] text-gray-500 leading-tight truncate">
            {[category, district].filter(Boolean).join(' · ')}
          </div>
        )}

        {/* Row 3: Rating */}
        {avgRating && avgRating > 0 ? (
          <div className="text-[11px] text-amber-600">
            ⭐ {avgRating.toFixed(1)}
            {ratingCount !== undefined && (
              <span className="text-gray-400 ml-1">({ratingCount})</span>
            )}
          </div>
        ) : null}

        {/* Row 4: Service tags */}
        {visibleTags.length > 0 && (
          <div className="flex gap-1 flex-wrap">
            {visibleTags.map((tag, i) => (
              <span
                key={i}
                className="text-[9px] bg-gray-100 text-gray-600 rounded-full px-2 py-0.5 border border-gray-200"
              >
                {tag}
              </span>
            ))}
            {extraTagCount > 0 && (
              <span className="text-[9px] text-gray-400 rounded-full px-1.5 py-0.5">
                +{extraTagCount}
              </span>
            )}
          </div>
        )}

        {/* Row 5: Action buttons */}
        {phone && (
          <div className="flex gap-2 mt-0.5">
            <a
              href={`tel:+91${phone}`}
              onClick={(e) => e.stopPropagation()}
              className="text-[10px] font-medium text-[#283618] border border-[#283618] rounded-full px-3 py-1 hover:bg-[#283618] hover:text-white transition-colors no-underline"
            >
              Call
            </a>
            <a
              href={`https://wa.me/91${phone}?text=Hi%2C%20I%20found%20you%20on%20wekerala`}
              target="_blank"
              rel="noopener noreferrer"
              onClick={(e) => e.stopPropagation()}
              className="text-[10px] font-medium text-green-700 border border-green-600 rounded-full px-3 py-1 hover:bg-green-600 hover:text-white transition-colors no-underline"
            >
              WhatsApp
            </a>
          </div>
        )}
      </div>
    </div>
  );
}
