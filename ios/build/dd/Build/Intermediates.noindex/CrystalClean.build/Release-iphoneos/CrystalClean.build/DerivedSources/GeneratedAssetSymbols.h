#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.yongji97.crystalclean";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "Brand" asset catalog color resource.
static NSString * const ACColorNameBrand AC_SWIFT_PRIVATE = @"Brand";

/// The "BrandStrong" asset catalog color resource.
static NSString * const ACColorNameBrandStrong AC_SWIFT_PRIVATE = @"BrandStrong";

/// The "Logo" asset catalog image resource.
static NSString * const ACImageNameLogo AC_SWIFT_PRIVATE = @"Logo";

#undef AC_SWIFT_PRIVATE
