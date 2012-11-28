horchatahelper
==============

A command line app to get quick food from GrubHub

## Config format

To make the app easy to use, you need to set up a file 'config.json' that sits next to get_grub.rb. It should look like this:

<pre>
{
    "grubhubHostname" : "www.grubhub.com",
    "apiKey" : "XXXXXXXXXXXXXXXXXXX",


    "credentials" :{
        "email" : "youremail@example.com",
        "password" :  "yourpassword"
    },

    "locations":
    {
        "Home" : {
            "address": "223 Main St",
            "address2": "#1",
            "city"  : "Oak Park",
            "state"  : "IL",
            "zip"   : "60302" ,
            "crossStreet": "Lake"
        },
        "Work" : {
            "address": "111 W Washington ",
            "address2": "Suite 2100",
            "city"  : "Chicago",
            "state"  : "IL",
            "zip"   : "60604",
            "crossStreet": "Clark"
        }
    },

    "freegrubs" : ["XXXXXXXXXXXXXXXXX"],
    "creditcard" : {
        "number" : "4111111111111111",
        "exp"    : "01/12",
        "cvv"    : "123"
    }
}
</pre>

## Example session

<pre>
~/horchatahelper$ ruby get_grub.rb --location Work --term "House Luncheon"
**** Had to geocode. You can skip this by adding ..."lat":"41.8832069", "lng":"-87.63126170000001" to your config for this address*****
Searching for House Luncheon at 111 W Washington .... found 1 restaurants

#############################
#  Friendship on the Lake
#  200 North Lake Front Drive
#  0.90 miles
#  Asian, Chinese, Japanese, Sushi, Szechwan, Cantonese, Dinner
#  1 matching items
#############################
How about...
- 'House Luncheon'. Ok? [y/N/Skiprestaurant]: y
Adding item to order...
adding option 1678921
adding option 1678927

#############################
####### ORDER SUMMARY #######
#############################
Order Id    : 23320174
Order method: pickup

======= ITEMS =======
(1) House Luncheon [Beef Chow Fun, Steamed Rice]   $ 8.95

======= MATH =======
subtotal:            $ 8.95
tax:                 $ 0.96
delivery:            $ 0
tip:                 $ 0.00
total:               $ 9.91
amount-due:          $ 9.91
Applying freegrub to order...

#############################
####### ORDER SUMMARY #######
#############################
Order Id    : 23320174
Order method: pickup

======= ITEMS =======
(1) House Luncheon [Beef Chow Fun, Steamed Rice]   $ 8.95

======= MATH =======
subtotal:            $ 8.95
tax:                 $ 0.96
delivery:            $ 0
tip:                 $ 0.00
total:               $ 9.91
giftcard:            $ -9.91
freegrubtotal:       $ -9.91
amount-due:          $ 0.00
...place order? This will send money! [y/N]: y
Final order check

#############################
####### ORDER SUMMARY #######
#############################
Order Id    : 23320174
Order method: pickup

======= ITEMS =======
(1) House Luncheon [Beef Chow Fun, Steamed Rice]   $ 8.95

======= MATH =======
subtotal:            $ 8.95
tax:                 $ 0.96
delivery:            $ 0
tip:                 $ 0.00
total:               $ 9.91
giftcard:            $ -9.91
freegrubtotal:       $ -9.91
amount-due:          $ 0.00

</pre>