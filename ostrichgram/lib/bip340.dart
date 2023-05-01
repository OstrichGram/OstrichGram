// Original python attribution: https://github.com/bitcoin/bips/blob/master/bip-0340/reference.py
// Code here is reinterpreted/ported from python to dart. Not audited.

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';


class ECPoint {
  final BigInt x;
  final BigInt y;

  ECPoint(this.x, this.y);

  @override
  String toString() => '($x, $y)';
}

class bip340 {



  void main() {
  String test_data_secret_key='B7E151628AED2A6ABF7158809CF4F3C762E7160F38B4DA56A784D9045190CFEF';
  String test_data_public_key='DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659';
  String test_data_aux_rand='0000000000000000000000000000000000000000000000000000000000000001';
  String test_data_message='243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89';
  String Stest_data_signature='6896BD60EEAE296DB48A229FF71DFE071BDE413E6D43F917DC8DCF8C78DE33418906D11AC976ABCCB20B091292BFF4EA897EFCB639EA871CFA95F6DE339E4B0A';
  String test_data_verification_result='TRUE';

  // NOT TEST DATA.  GLOBAL VARIABLES ARE PART OF BIP340.
  BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  BigInt n = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);
  ECPoint G = ECPoint(BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798',radix:16), BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8',radix:16));


  } //END OF MAIN

  static BigInt getX(ECPoint point) {
  return point.x;
  }


  static BigInt getY(ECPoint point) {
  return point.y;
  }

  static ECPoint? point_mul(ECPoint? P, BigInt n, BigInt p) {
  //Initialize as null, not zero or it wont work because of the way elliptic curve points work.
  ECPoint? R;
  for (int i = 0; i < 256; i++) {
  if ((n >> i) & BigInt.one == BigInt.one) {
  R = point_add(R, P, p);
  }
  P = point_add(P, P,p);
  }
  return R;
  }

  static Uint8List bytes_from_int(BigInt x) {
  // Calculate the byte length of the number
  int byteLength = 32;

  // Create a Uint8List to store the bytes
  var byteArray = Uint8List(byteLength);

  // Iterate over the bytes, most significant byte first, and store them in the Uint8List
  for (int i = 0; i < byteLength; i++) {
  byteArray[byteLength - 1 - i] = ((x >> (8 * i)) & BigInt.from(0xFF)).toInt();

  }

  return byteArray;
  }


  static BigInt int_from_bytes(Uint8List bytes) {
  return bytes.fold<BigInt>(
  BigInt.zero, (BigInt prev, int byte) => (prev << 8) | BigInt.from(byte));
  }


  static Uint8List bytes_from_point(ECPoint P) {
  return bytes_from_int(getX(P));
  }


  static ECPoint? point_add(ECPoint? p1, ECPoint? p2, BigInt p) {
  if (p1 == null) {
  return p2;
  }
  if (p2 == null) {
  return p1;
  }
  if (getX(p1) == getX(p2) && getY(p1) != getY(p2)) {
  return null;
  }

  BigInt lam;
  if (p1.x == p2.x && p1.y == p2.y) {
  BigInt three = BigInt.from(3);
  BigInt two = BigInt.two;
  BigInt numerator = three * getX(p1) * getX(p1);
  BigInt denominator = getY(p1) * two;
  BigInt exponent = p - two;
  BigInt inverse = denominator.modPow(exponent, p);
  lam = (numerator * inverse) % p;
  } else {
  BigInt yDiff = getY(p2) - getY(p1);
  BigInt xDiff = getX(p2) - getX(p1);
  BigInt exponent = p - BigInt.two;
  BigInt inverse = xDiff.modPow(exponent, p);
  lam = (yDiff * inverse) % p;
  }

  BigInt x3 = (lam * lam - getX(p1) - getX(p2)) % p;
  return ECPoint(x3, (lam * (getX(p1) - x3) - getY(p1)) % p);
  } //END of point_add.


  static Uint8List pubkey_gen(Uint8List seckey) {



    BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  BigInt n = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);
  ECPoint G = ECPoint(BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798',radix:16), BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8',radix:16));


  BigInt d0 = int_from_bytes(seckey);
  if (!(BigInt.one <= d0 && d0 <= n - BigInt.one)) {
  throw ArgumentError('The secret key must be an integer in the range 1..n-1.');
  }
  ECPoint? P = point_mul(G, d0, p);
  if (P == null) {
  throw StateError('Unexpected null value for P.');
  }
  return bytes_from_point(P);
  }

// CONVERT HEX STRING TO BYTES.

  static Uint8List hexStringToUint8List(String hex) {
  if (hex.length % 2 != 0) {
  hex = '0' + hex;
  }
  return Uint8List.fromList(List<int>.generate(hex.length ~/ 2, (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16)));
  }

  static Uint8List xor_bytes(Uint8List b0, Uint8List b1) {
  return Uint8List.fromList([
  for (int i = 0; i < b0.length; i++)
  b0[i] ^ b1[i]
  ]);
  }

  static ECPoint? lift_x(BigInt x, BigInt p) {
  if (x >= p) {
  return null;
  }
  BigInt ySq = (x.modPow(BigInt.from(3), p) + BigInt.from(7)) % p;
  BigInt y = ySq.modPow((p + BigInt.one) ~/ BigInt.from(4), p);
  if (y.modPow(BigInt.two, p) != ySq) {
  return null;
  }
  return ECPoint(x, y.isEven ? y : p - y);
  }

  static Uint8List tagged_hash(String tag, Uint8List msg) {
  var tagBytes = utf8.encode(tag);
  var tagHash = sha256.convert(tagBytes).bytes;
  return Uint8List.fromList(sha256.convert(tagHash + tagHash + msg).bytes);
  }

  static bool has_even_y(ECPoint P) {
  if (P == null) {
  throw ArgumentError('P cannot be null.');
  }
  return getY(P) % BigInt.two == BigInt.zero;
  }


static Uint8List schnorr_sign(Uint8List msg, Uint8List seckey, Uint8List auxRand) {

  BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
  BigInt n = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);
  ECPoint G = ECPoint(BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798',radix:16), BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8',radix:16));



  if (msg.length != 32) {
  throw ArgumentError('The message must be a 32-byte array.');
  }
  BigInt d0 = int_from_bytes(seckey);
  if (!(BigInt.one <= d0 && d0 <= n - BigInt.one)) {
  throw ArgumentError('The secret key must be an integer in the range 1..n-1.');
  }
  if (auxRand.length != 32) {
  throw ArgumentError('aux_rand must be 32 bytes instead of ${auxRand.length}.');
  }
  ECPoint? P = point_mul(G, d0, p);
  if (P == null) {
  throw StateError('Unexpected null value for P.');
  }
  BigInt d = d0;
  if (!has_even_y(P)) {
  d = n - d0;
  }
  Uint8List t = xor_bytes(bytes_from_int(d), tagged_hash("BIP0340/aux", auxRand));
  BigInt k0 = int_from_bytes(tagged_hash("BIP0340/nonce", Uint8List.fromList(t + bytes_from_point(P) + msg))) % n;

  if (k0 == BigInt.zero) {
  throw StateError('Failure. This happens only with negligible probability.');
  }
  ECPoint? R = point_mul(G, k0, p);
  if (R == null) {
  throw StateError('Unexpected null value for R.');
  }
  BigInt k = k0;
  if (!has_even_y(R)) {
  k = n - k0;
  }
  BigInt e = int_from_bytes(tagged_hash("BIP0340/challenge", Uint8List.fromList(bytes_from_point(R) + bytes_from_point(P) + msg))) % n;
  Uint8List sig = Uint8List.fromList(bytes_from_point(R) + bytes_from_int((k + e * d) % n));


  if (!schnorr_verify(msg, bytes_from_point(P), sig)) {
  throw StateError('The created signature does not pass verification.');
  }

  return sig;
  }

  static bool schnorr_verify(Uint8List msg, Uint8List pubkey, Uint8List sig) {


    BigInt p = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', radix: 16);
    BigInt n = BigInt.parse('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141', radix: 16);
    ECPoint G = ECPoint(BigInt.parse('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798',radix:16), BigInt.parse('483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8',radix:16));


    if (msg.length != 32) {
  throw ArgumentError('The message must be a 32-byte array.');
  }
  if (pubkey.length != 32) {
  throw ArgumentError('The public key must be a 32-byte array.');
  }
  if (sig.length != 64) {
  throw ArgumentError('The signature must be a 64-byte array.');
  }

  ECPoint? P = lift_x(int_from_bytes(pubkey), p);
  BigInt r = int_from_bytes(sig.sublist(0, 32));
  BigInt s = int_from_bytes(sig.sublist(32, 64));

  if (P == null || r >= p || s >= n) {
  return false;
  }

  BigInt e = int_from_bytes(tagged_hash("BIP0340/challenge", Uint8List.fromList(sig.sublist(0, 32) + pubkey + msg))) % n;
  ECPoint? R = point_add(point_mul(G, s, p), point_mul(P, n - e, p), p);

  if (R == null || !has_even_y(R) || getX(R) != r) {
  return false;
  }

  return true;
  }


} //END CLASS BIP340.

