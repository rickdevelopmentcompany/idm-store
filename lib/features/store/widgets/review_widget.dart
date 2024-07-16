import 'package:sixam_mart_store/common/widgets/rating_bar_widget.dart';
import 'package:sixam_mart_store/features/store/domain/models/review_model.dart';
import 'package:sixam_mart_store/util/dimensions.dart';
import 'package:sixam_mart_store/util/styles.dart';
import 'package:sixam_mart_store/common/widgets/custom_image_widget.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ReviewWidget extends StatelessWidget {
  final ReviewModel review;
  final bool hasDivider;
  final bool fromStore;
  const ReviewWidget({super.key, required this.review, required this.hasDivider, required this.fromStore});

  @override
  Widget build(BuildContext context) {
    return Column(children: [

      Row(children: [

        ClipOval(
          child: CustomImageWidget(
            image: '${fromStore ? review.itemImageFullUrl : review.customer != null ? review.customer!.imageFullUrl : ''}',
            height: 60, width: 60, fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: Dimensions.paddingSizeSmall),

        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

          Text(
            fromStore ? review.itemName! : review.customer != null ?'${ review.customer!.fName} ${ review.customer!.lName}' : 'customer_not_found'.tr,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeSmall, color: review.customerName != null ? Theme.of(context).textTheme.displayLarge!.color : Theme.of(context).disabledColor),
          ),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),

          RatingBarWidget(rating: review.rating!.toDouble(), ratingCount: null, size: 15),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),

          fromStore ? Text(
            review.customerName != null ? review.customerName! : 'customer_not_found'.tr,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: robotoMedium.copyWith(fontSize: Dimensions.fontSizeExtraSmall,
                color: review.customerName != null ? Theme.of(context).textTheme.displayLarge!.color : Theme.of(context).disabledColor),
          ) : const SizedBox(),
          const SizedBox(height: Dimensions.paddingSizeExtraSmall),

          Text(review.comment ?? '', style: robotoRegular.copyWith(fontSize: Dimensions.fontSizeExtraSmall, color: Theme.of(context).disabledColor)),

        ])),

      ]),

      hasDivider ? Padding(
        padding: const EdgeInsets.only(left: 70),
        child: Divider(color: Theme.of(context).disabledColor),
      ) : const SizedBox(),

    ]);
  }
}
