���P   S�sZ1Z>�2 ͮ
ZSDOS Time Stamp Loader, Ver 1.1
  Copyright (C) 1988  by H.F.Bower / C.W.Cotrill

 * >�O>��G>Z��  ��� ��� ����! ~� #~��� ��S,z�(! �~(!C F+N++V+^`i: �g�K	W. ��B�. ".�S0!� ~##������~#�/��~�/�9ͮ
 Purpose:
   Load a ZSDOS Time Stamp module and patch in place.
   Set Stamping method & Clock type with SETUPZST.

 Usage :
   Name<cr>      <-- Load the module contained
   Name /L<cr>   <-- List the installed module
   Name /R<cr>   <-- Remove the installed module

 ͮ This is:  !ʹ���L Zͮ
    The Installed module is :  ��(
��(;ͮ- Empty - �/ͮ- Not removable - ��R -ͮ
    Removing :  ��(����A�;��h�ͮ
 ++ Bad option ͮ...aborting ;0� :� :�(pͮ
 ++ Incorrect DOS or Version Number ͮ ++ ���{Z���%� �ͮ
 ++ Can't remove the current clock! ��*|� *0�[ }�|�8��[ 
��R"�j*#|��j�[,! �~�:! N#F! 	MD�##f. ��R8��*�K	���R�f�ͮ
 ++ Not enough space in NZCOM User Area
 Clock requires  �+|��}��ͮH bytes of user space.
 �(ͮ
 ++ NZ-COM Not Present...Can't load ��C��(P���A�ͮ
 +++  �;�ͮ - Loaded, Replace it (Y/[N])? :  � �_�Y��(�����K!�
��[ 
!�
{��(}� �N#����0	V+^�	�s#r#��!�
�[�K 
��!	^#V! 	� ���!��*�[��8*ͮ ++Clock not working ...aborting
 �  !7�*|�(###���!ʹͮ ...loaded at  *|��}��H����ͮ Clock is :  !ʹ���[,�K  �3ENV�ʹ��~#_������ ^#V�ʹ�����
��� �������Ɛ'�@'_�*.$ ^#V�}��|�<�DateStamper in User Space, 15 Mar 1993                                                                                                                                                                                                                         B/P BIOS Vector         1.0   Interface for B/P BIOS Clock
                                                                                                                                                                                                   .�SB.�A.~�`0(  x��* .�:.�����A.�~�'(�0�`'�'ط��      !  � !;.�                                                                                                                                                                                     p                                                                                                                              �  �+ ò     " PCHp  H� � � � � ZDS V1.1 ��z�(! �~(
!B ~#fo ! �	"5� 0͉ � |�S� !!� ~� 5! �!  ���## s#r͊ *	 ��|�����͢ �͢ 7+*5	Nwy#����> �(�2� *5% w+w+V+^+r+s�͊ * � 
2f"�& �o�~>��   2f"��C:�S$���G�3�|�g}��(l  �/R ����8�!f�w�E ���? ���YW�)0������ͽ� -�WG *$�[�::� ���(���ͽw*��>>��  �/��W:;_� 6 #�J<��H��= � �*$��#���w*5	͉ '�1�����*5N#F�{�D���cP�>�2����> �()<2� �~��O#��� ����J`i�3��r+s����$�!  ��              �y�( �V�Y �!  |� * .N"]�    �U@        � �H  	  �   	 @ � @�  @�    @!   �      $  '                                                                  