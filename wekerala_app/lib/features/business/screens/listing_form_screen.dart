import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_text_field.dart';

const _keralaDistricts = [
  'Thiruvananthapuram', 'Kollam', 'Pathanamthitta', 'Alappuzha', 'Kottayam',
  'Idukki', 'Ernakulam', 'Thrissur', 'Palakkad', 'Malappuram',
  'Kozhikode', 'Wayanad', 'Kannur', 'Kasaragod',
];

const _serviceTypes = [
  'Plumber', 'Electrician', 'Carpenter', 'Painter', 'Welder',
  'AC Repair', 'Cleaning', 'Pest Control', 'Driving', 'Cooking',
  'Tutoring', 'Photography', 'Tailoring', 'Mason', 'Other',
];

const _theaterTypes = ['Multiplex', 'Single Screen', 'IMAX', '4DX', 'Drive-in'];
const _theaterFacilities = ['AC', 'Parking', 'Food Court', 'Online Booking', 'Recliner Seats', 'Dolby Sound'];

const _hotelCategories = ['Budget', 'Mid-range', 'Luxury', 'Resort', 'Heritage', 'Homestay'];
const _hotelAmenities = ['Pool', 'Gym', 'Restaurant', 'WiFi', 'AC', 'Parking', 'Room Service', 'Laundry'];

const _kCuisineOptions = [
  'Kerala', 'North Indian', 'Chinese', 'Continental', 'Biryani',
  'Fast Food', 'Seafood', 'Vegan', 'Bakery', 'Multi-cuisine',
];
const _kDiningOptions = ['Dine-in', 'Takeaway', 'Delivery'];
const _vegOptions = ['Veg', 'Non-Veg', 'Both'];

const _kBeautyServices = [
  'Haircut', 'Hair Color', 'Facial', 'Waxing', 'Threading',
  'Bridal Makeup', 'Mehndi', 'Spa', 'Massage', 'Manicure', 'Pedicure',
];
const _genderOptions = ['Ladies', 'Gents', 'Unisex'];
const _availabilityOptions = ['On-call', 'By Appointment', 'Both'];

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key});

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Base fields
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _externalUrl = TextEditingController();
  String? _district;

  // Services
  String? _serviceType;
  final _experience = TextEditingController();
  final _priceRange = TextEditingController();
  String? _availability;
  final List<String> _serviceAreas = [];

  // Theaters
  String? _theaterType;
  final _screensCtrl = TextEditingController();
  final _ticketPriceRange = TextEditingController();
  final List<String> _facilities = [];
  final _bookingUrl = TextEditingController();

  // Hotels
  String? _hotelCategory;
  final _pricePerNight = TextEditingController();
  final List<String> _amenities = [];
  final _totalRoomsCtrl = TextEditingController();
  final _checkIn = TextEditingController();
  final _checkOut = TextEditingController();

  // Restaurants
  final List<String> _cuisineTypes = [];
  final List<String> _diningOptions = [];
  String? _isVeg;
  final _avgCostForTwo = TextEditingController();
  final _specialities = TextEditingController();

  // Beauty
  final List<String> _serviceList = [];
  String? _gender;
  bool _homeVisitAvailable = false;
  bool _appointmentRequired = false;
  final _beautyPriceRange = TextEditingController();

  bool _saving = false;
  String _businessType = 'services';

  @override
  void initState() {
    super.initState();
    _loadBusinessType();
  }

  Future<void> _loadBusinessType() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return;
    final types = List<String>.from(doc.data()?['businessTypes'] as List? ?? []);
    if (types.isNotEmpty && mounted) {
      setState(() => _businessType = types.first);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_district == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a district')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final data = <String, dynamic>{
        'ownerId': uid,
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'location': _location.text.trim(),
        'district': _district,
        'description': _description.text.trim(),
        'externalUrl': _externalUrl.text.trim(),
        'photos': [],
        'isApproved': false,
        'createdAt': Timestamp.now(),
      };

      switch (_businessType) {
        case 'services':
          data['serviceType'] = _serviceType ?? '';
          data['experience'] = _experience.text.trim();
          data['priceRange'] = _priceRange.text.trim();
          data['availability'] = _availability ?? '';
          data['serviceAreas'] = List<String>.from(_serviceAreas);
          break;
        case 'theaters':
          data['theaterType'] = _theaterType ?? '';
          data['screens'] = int.tryParse(_screensCtrl.text.trim()) ?? 1;
          data['ticketPriceRange'] = _ticketPriceRange.text.trim();
          data['facilities'] = List<String>.from(_facilities);
          data['bookingUrl'] = _bookingUrl.text.trim();
          break;
        case 'hotels':
          data['hotelCategory'] = _hotelCategory ?? '';
          data['pricePerNight'] = _pricePerNight.text.trim();
          data['amenities'] = List<String>.from(_amenities);
          data['totalRooms'] = int.tryParse(_totalRoomsCtrl.text.trim()) ?? 0;
          data['checkIn'] = _checkIn.text.trim();
          data['checkOut'] = _checkOut.text.trim();
          break;
        case 'restaurants':
          data['cuisineTypes'] = List<String>.from(_cuisineTypes);
          data['diningOptions'] = List<String>.from(_diningOptions);
          data['isVeg'] = _isVeg ?? '';
          data['avgCostForTwo'] = _avgCostForTwo.text.trim();
          data['specialities'] = _specialities.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          break;
        case 'beauty':
          data['serviceList'] = List<String>.from(_serviceList);
          data['gender'] = _gender ?? '';
          data['homeVisitAvailable'] = _homeVisitAvailable;
          data['appointmentRequired'] = _appointmentRequired;
          data['priceRange'] = _beautyPriceRange.text.trim();
          break;
      }

      await FirebaseFirestore.instance.collection(_businessType).add(data);
      if (mounted) context.go('/business/home');
    } catch (e) {
      debugPrint('ListingForm save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _location.dispose();
    _description.dispose(); _externalUrl.dispose();
    _experience.dispose(); _priceRange.dispose();
    _screensCtrl.dispose(); _ticketPriceRange.dispose(); _bookingUrl.dispose();
    _pricePerNight.dispose(); _totalRoomsCtrl.dispose(); _checkIn.dispose(); _checkOut.dispose();
    _avgCostForTwo.dispose(); _specialities.dispose();
    _beautyPriceRange.dispose();
    super.dispose();
  }

  List<Widget> _typeFields() {
    switch (_businessType) {
      case 'services':
        return [
          _DropdownField(
            label: 'Service Type *',
            hint: 'Select service',
            value: _serviceType,
            items: _serviceTypes,
            onChanged: (v) => setState(() => _serviceType = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _experience,
            label: 'Years of Experience',
            hint: 'e.g. 5',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _priceRange,
            label: 'Price Range',
            hint: 'e.g. ₹200-500/visit',
          ),
          const SizedBox(height: 16),
          _RadioField(
            label: 'Availability',
            value: _availability,
            options: _availabilityOptions,
            onChanged: (v) => setState(() => _availability = v),
          ),
          const SizedBox(height: 16),
          _MultiChipField(
            label: 'Districts You Cover',
            options: _keralaDistricts,
            selected: _serviceAreas,
            onToggle: (v) => setState(() {
              _serviceAreas.contains(v) ? _serviceAreas.remove(v) : _serviceAreas.add(v);
            }),
          ),
        ];

      case 'theaters':
        return [
          _DropdownField(
            label: 'Theater Type *',
            hint: 'Select type',
            value: _theaterType,
            items: _theaterTypes,
            onChanged: (v) => setState(() => _theaterType = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _screensCtrl,
            label: 'Number of Screens',
            hint: 'e.g. 4',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _ticketPriceRange,
            label: 'Ticket Price Range',
            hint: 'e.g. ₹120-300',
          ),
          const SizedBox(height: 16),
          _MultiChipField(
            label: 'Facilities',
            options: _theaterFacilities,
            selected: _facilities,
            onToggle: (v) => setState(() {
              _facilities.contains(v) ? _facilities.remove(v) : _facilities.add(v);
            }),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _bookingUrl,
            label: 'Online Booking URL (optional)',
            hint: 'BookMyShow / Paytm link',
            keyboardType: TextInputType.url,
          ),
        ];

      case 'hotels':
        return [
          _DropdownField(
            label: 'Category *',
            hint: 'Select category',
            value: _hotelCategory,
            items: _hotelCategories,
            onChanged: (v) => setState(() => _hotelCategory = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _pricePerNight,
            label: 'Price Per Night',
            hint: 'e.g. ₹1500-3000',
          ),
          const SizedBox(height: 16),
          _MultiChipField(
            label: 'Amenities',
            options: _hotelAmenities,
            selected: _amenities,
            onToggle: (v) => setState(() {
              _amenities.contains(v) ? _amenities.remove(v) : _amenities.add(v);
            }),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _totalRoomsCtrl,
            label: 'Total Rooms',
            hint: 'e.g. 30',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _checkIn,
                  label: 'Check-in Time',
                  hint: '12:00 PM',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _checkOut,
                  label: 'Check-out Time',
                  hint: '11:00 AM',
                ),
              ),
            ],
          ),
        ];

      case 'restaurants':
        return [
          _MultiChipField(
            label: 'Cuisine Types',
            options: _kCuisineOptions,
            selected: _cuisineTypes,
            onToggle: (v) => setState(() {
              _cuisineTypes.contains(v) ? _cuisineTypes.remove(v) : _cuisineTypes.add(v);
            }),
          ),
          const SizedBox(height: 16),
          _MultiChipField(
            label: 'Dining Options',
            options: _kDiningOptions,
            selected: _diningOptions,
            onToggle: (v) => setState(() {
              _diningOptions.contains(v) ? _diningOptions.remove(v) : _diningOptions.add(v);
            }),
          ),
          const SizedBox(height: 16),
          _RadioField(
            label: 'Food Type',
            value: _isVeg,
            options: _vegOptions,
            onChanged: (v) => setState(() => _isVeg = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _avgCostForTwo,
            label: 'Average Cost for Two',
            hint: 'e.g. ₹300-600',
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _specialities,
            label: 'Specialities (comma-separated)',
            hint: 'e.g. Karimeen, Appam, Biryani',
          ),
        ];

      case 'beauty':
        return [
          _MultiChipField(
            label: 'Services Offered',
            options: _kBeautyServices,
            selected: _serviceList,
            onToggle: (v) => setState(() {
              _serviceList.contains(v) ? _serviceList.remove(v) : _serviceList.add(v);
            }),
          ),
          const SizedBox(height: 16),
          _RadioField(
            label: 'Serves',
            value: _gender,
            options: _genderOptions,
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _beautyPriceRange,
            label: 'Price Range',
            hint: 'e.g. ₹200-2000',
          ),
          const SizedBox(height: 16),
          _SwitchField(
            label: 'Home Visit Available',
            value: _homeVisitAvailable,
            onChanged: (v) => setState(() => _homeVisitAvailable = v),
          ),
          const SizedBox(height: 8),
          _SwitchField(
            label: 'Appointment Required',
            value: _appointmentRequired,
            onChanged: (v) => setState(() => _appointmentRequired = v),
          ),
        ];

      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Business Details', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: BackButton(onPressed: () => context.go('/business/type')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Tell us about your business',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This info will appear on your Oratas listing.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            AppTextField(
              controller: _name,
              label: 'Business Name *',
              hint: 'e.g. Rajan Electricals',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _phone,
              label: 'Contact Phone *',
              hint: '10-digit number',
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 10) ? 'Enter valid phone' : null,
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _location,
              label: 'Full Address *',
              hint: 'Street, area, city',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Address is required' : null,
            ),
            const SizedBox(height: 16),

            _DropdownField(
              label: 'District *',
              hint: 'Select district',
              value: _district,
              items: _keralaDistricts,
              onChanged: (v) => setState(() => _district = v),
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _description,
              label: 'Short Description',
              hint: 'What you offer, specialties, timings…',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            AppTextField(
              controller: _externalUrl,
              label: 'Your Website URL (optional)',
              hint: 'https://yourbusiness.com',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 24),

            if (_typeFields().isNotEmpty) ...[
              _SectionHeader(label: _typeSectionLabel()),
              const SizedBox(height: 16),
              ..._typeFields(),
              const SizedBox(height: 16),
            ],

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Submit Listing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _typeSectionLabel() {
    switch (_businessType) {
      case 'services': return 'Service Details';
      case 'theaters': return 'Theater Details';
      case 'hotels': return 'Hotel Details';
      case 'restaurants': return 'Restaurant Details';
      case 'beauty': return 'Beauty & Wellness Details';
      default: return 'Details';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.textSecondary.withValues(alpha: 0.3))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.accent,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.textSecondary.withValues(alpha: 0.3))),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _DropdownField({
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppColors.textSecondary)),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _RadioField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final void Function(String?) onChanged;

  const _RadioField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.map((opt) {
            final selected = value == opt;
            return ChoiceChip(
              label: Text(opt),
              selected: selected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: selected ? AppColors.background : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide.none,
              onSelected: (_) => onChanged(opt),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MultiChipField extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final void Function(String) onToggle;

  const _MultiChipField({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((opt) {
            final isSelected = selected.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              selectedColor: AppColors.primary,
              checkmarkColor: AppColors.background,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.background : AppColors.textPrimary,
                fontSize: 12,
              ),
              backgroundColor: AppColors.surface,
              side: BorderSide.none,
              onSelected: (_) => onToggle(opt),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
